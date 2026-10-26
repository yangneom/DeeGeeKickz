import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { officialWebBase } from "../_shared/web_base.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// CHECKOUT_REUSE v2
//
// Where customers return to after the hosted PayMongo page (GCash / card).
// If this secret is missing, web customers are sent to localhost, which only
// works on the developer's own computer.
// Where a web customer is sent back to after paying. ONLY the official domain (or local
// development) is accepted; anything else in the secret is ignored. This is a browser
// redirect, NOT proof of payment: the order is marked paid by the PayMongo webhook.
const webBaseUrl = officialWebBase(Deno.env.get("WEB_BASE_URL"));

const PAYMONGO_API = "https://api.paymongo.com/v1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status: number) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Every failure is a short readable message plus a code the app can act on.
// Raw PayMongo errors are logged for you, never sent to the browser.
function failure(status: number, code: string, message: string) {
  return json({ error: message, code }, status);
}

function paymongoHeaders(): Record<string, string> {
  const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";
  return {
    "Content-Type": "application/json",
    "Authorization": `Basic ${btoa(secretKey + ":")}`,
  };
}

// What PayMongo says about a payment page we created earlier.
type SessionState =
  | { kind: "active"; checkoutUrl: string } // still open: reuse it
  | { kind: "paid" }                        // money was received
  | { kind: "unusable" }                    // expired, or PayMongo no longer knows it
  | { kind: "unknown" };                    // PayMongo could not be asked

async function inspectSession(sessionId: string): Promise<SessionState> {
  let res: Response;
  try {
    res = await fetch(
      `${PAYMONGO_API}/checkout_sessions/${encodeURIComponent(sessionId)}`,
      { headers: paymongoHeaders() },
    );
  } catch (_) {
    return { kind: "unknown" };
  }

  if (res.status === 404) return { kind: "unusable" };
  if (!res.ok) return { kind: "unknown" };

  const body = await res.json().catch(() => ({}));
  const attrs = body?.data?.attributes ?? {};
  const payments = Array.isArray(attrs.payments) ? attrs.payments : [];

  const paid =
    payments.some((p: any) => p?.attributes?.status === "paid") ||
    attrs.payment_intent?.attributes?.status === "succeeded";
  if (paid) return { kind: "paid" };

  if (attrs.status === "active" && typeof attrs.checkout_url === "string") {
    return { kind: "active", checkoutUrl: attrs.checkout_url };
  }
  return { kind: "unusable" };
}

async function expireSession(sessionId: string) {
  try {
    await fetch(
      `${PAYMONGO_API}/checkout_sessions/${encodeURIComponent(sessionId)}/expire`,
      { method: "POST", headers: paymongoHeaders() },
    );
  } catch (_) {
    console.error("Could not expire the extra session", sessionId);
  }
}

serve(async (req) => {
  // This MUST run before any auth check. A browser's CORS preflight
  // OPTIONS request never carries an Authorization header by design.
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return json({ error: "Missing authorization" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: { user } } = await supabase.auth.getUser(
    authHeader.replace("Bearer ", ""),
  );
  if (!user) {
    return json({ error: "Invalid session" }, 401);
  }

  try {
    // NOTE: any `amount` sent by the app is deliberately IGNORED. The amount
    // charged always comes from the order row below, never from the client.
    const { orderId, customerName, customerEmail, paymentMethod, platform } =
      await req.json();

    const orderIdNumber = Number(orderId);
    if (!Number.isInteger(orderIdNumber) || orderIdNumber <= 0) {
      return failure(400, "invalid_order", "Invalid order.");
    }

    // ── Fetch the REAL order: ownership, status and true amount ──
    const { data: orderRow, error: orderError } = await supabase
      .from("orders")
      .select("user_id, total_amount, order_status, order_type")
      .eq("order_id", orderIdNumber)
      .single();

    if (orderError || !orderRow) {
      return failure(404, "order_not_found", "Order not found.");
    }

    // The order's owner may pay for it. The one exception is a walk-in
    // (In-Store) QR sale, which is started by cashier/admin staff.
    if (orderRow.user_id !== user.id) {
      let allowed = false;
      if (orderRow.order_type === "In-Store") {
        const { data: profile } = await supabase
          .from("users")
          .select("role")
          .eq("id", user.id)
          .single();
        allowed = ["Cashier", "Admin", "Super Admin"].includes(
          profile?.role ?? "",
        );
      }
      if (!allowed) {
        return failure(403, "forbidden", "Forbidden.");
      }
    }

    // A cancelled or already-paid order must never get a new payment link.
    if (orderRow.order_status !== "Awaiting Payment") {
      return failure(
        409,
        "order_not_awaiting_payment",
        "This order is not awaiting payment.",
      );
    }

    const amount = Number(orderRow.total_amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return failure(400, "invalid_amount", "Invalid order amount.");
    }
    const amountInCentavos = Math.round(amount * 100);

    // ── Has this order ALREADY started a payment? ──
    // Clicking Pay again (or refreshing, or coming back after cancelling)
    // must not open a second, separate payment page for the same order:
    // that is how someone gets charged twice.
    const { data: paymentRow } = await supabase
      .from("payment")
      .select("reference_number, gateway_response")
      .eq("order_id", orderIdNumber)
      .maybeSingle();

    const previousRef: string | null = paymentRow?.reference_number ?? null;

    if (previousRef && String(previousRef).startsWith("cs_")) {
      const state = await inspectSession(previousRef);

      if (state.kind === "paid") {
        // Money arrived but the confirmation has not been processed yet.
        return failure(
          409,
          "already_paid",
          "We already received a payment for this order and are confirming it. " +
            "Please check your order history in a moment.",
        );
      }
      if (state.kind === "active") {
        console.log("create-checkout: reused open session for order", orderIdNumber);
        return json(
          { checkoutUrl: state.checkoutUrl, sessionId: previousRef, reused: true },
          200,
        );
      }
      if (state.kind === "unknown") {
        // Do not guess: opening a second page while the first might be live
        // or paid is exactly the risk.
        return failure(
          503,
          "cannot_verify_previous_attempt",
          "We couldn't check your earlier payment attempt. Please wait a moment and try again.",
        );
      }
      // "unusable" (expired): carry on and create a fresh page.
    }

    const method = String(paymentMethod ?? "").toLowerCase();
    const methodTypes =
      method === "gcash"
        ? ["gcash"]
        : method === "card" || method === "credit/debit card"
        ? ["card"]
        : ["gcash", "card"];

    if (platform !== "mobile" && webBaseUrl.startsWith("http://localhost")) {
      console.warn(
        "create-checkout: WEB_BASE_URL is not set, so customers are being sent back to localhost.",
      );
    }

    const body = {
      data: {
        attributes: {
          billing: {
            name: customerName,
            email: customerEmail,
          },
          send_email_receipt: false,
          show_description: true,
          show_line_items: true,
          line_items: [
            {
              currency: "PHP",
              amount: amountInCentavos,
              name: `DeeGee Kickz Order #${orderIdNumber}`,
              quantity: 1,
            },
          ],
          payment_method_types: methodTypes,
          success_url: platform === "mobile"
            ? `dgeekickz://payment-success?order=${orderIdNumber}`
            : `${webBaseUrl}/order-history?order=${orderIdNumber}`,
          cancel_url: platform === "mobile"
            ? `dgeekickz://payment-cancel?order=${orderIdNumber}`
            : `${webBaseUrl}/order-history?cancelled=1`,
          description: `Order #${orderIdNumber} DeeGee Kickz`,
        },
      },
    };

    const response = await fetch(`${PAYMONGO_API}/checkout_sessions`, {
      method: "POST",
      headers: paymongoHeaders(),
      body: JSON.stringify(body),
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      // The details go to YOUR logs (Dashboard, Edge Functions, create-checkout,
      // Logs). The customer gets a plain sentence.
      console.error(
        "PayMongo checkout error:",
        response.status,
        JSON.stringify(data?.errors ?? data),
      );

      if (response.status === 429) {
        return failure(
          429,
          "rate_limited",
          "Too many payment attempts. Please wait a moment and try again.",
        );
      }
      if (response.status === 401 || response.status === 403 || response.status >= 500) {
        return failure(
          502,
          "payment_unavailable",
          "Online payment is temporarily unavailable. Please try again later or choose another payment method.",
        );
      }
      return failure(
        502,
        "payment_rejected",
        "We couldn't start the payment for this order. Please try again, or choose another payment method.",
      );
    }

    const checkoutUrl = data.data.attributes.checkout_url as string;
    const sessionId = data.data.id as string;

    // ── Save the new session, but ONLY if nobody else saved one first ──
    // Two quick clicks both reach this point. The update below succeeds for
    // the first and matches no row for the second, which then closes its own
    // extra payment page and hands back the winner's.
    let claim = supabase
      .from("payment")
      .update({ reference_number: sessionId, gateway_response: checkoutUrl })
      .eq("order_id", orderIdNumber);
    claim = previousRef === null
      ? claim.is("reference_number", null)
      : claim.eq("reference_number", previousRef);

    const { data: claimed, error: claimError } = await claim.select("reference_number");

    if (claimError) {
      console.error("Failed to save session ID:", claimError);
      // Don't block the user: still return the URL, but log it.
    } else if (!claimed || claimed.length === 0) {
      const { data: current } = await supabase
        .from("payment")
        .select("reference_number, gateway_response")
        .eq("order_id", orderIdNumber)
        .maybeSingle();

      if (
        current?.reference_number &&
        current.reference_number !== sessionId &&
        String(current.reference_number).startsWith("cs_") &&
        current.gateway_response
      ) {
        await expireSession(sessionId);
        console.log("create-checkout: lost a double-click race for order", orderIdNumber);
        return json(
          {
            checkoutUrl: current.gateway_response,
            sessionId: current.reference_number,
            reused: true,
          },
          200,
        );
      }
      console.error("No payment row was updated for order", orderIdNumber);
    }

    return json({ checkoutUrl, sessionId }, 200);
  } catch (e) {
    console.error("create-checkout error:", e);
    // Don't leak internal error text to the client.
    return failure(500, "unexpected", "Could not start the payment. Please try again.");
  }
});