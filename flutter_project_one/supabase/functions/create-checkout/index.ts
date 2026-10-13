import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const webBaseUrl = Deno.env.get("WEB_BASE_URL") ?? "http://localhost:5000";

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
      return json({ error: "Invalid order" }, 400);
    }

    // ── Fetch the REAL order: ownership, status and true amount ──
    const { data: orderRow, error: orderError } = await supabase
      .from("orders")
      .select("user_id, total_amount, order_status, order_type")
      .eq("order_id", orderIdNumber)
      .single();

    if (orderError || !orderRow) {
      return json({ error: "Order not found" }, 404);
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
        return json({ error: "Forbidden" }, 403);
      }
    }

    // A cancelled or already-paid order must never get a new payment link.
    if (orderRow.order_status !== "Awaiting Payment") {
      return json({ error: "This order is not awaiting payment" }, 409);
    }

    const amount = Number(orderRow.total_amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return json({ error: "Invalid order amount" }, 400);
    }
    const amountInCentavos = Math.round(amount * 100);

    const method = String(paymentMethod ?? "").toLowerCase();
    const methodTypes =
      method === "gcash"
        ? ["gcash"]
        : method === "card" || method === "credit/debit card"
        ? ["card"]
        : ["gcash", "card"];

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

    const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";

    const response = await fetch(
      "https://api.paymongo.com/v1/checkout_sessions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Basic ${btoa(secretKey + ":")}`,
        },
        body: JSON.stringify(body),
      },
    );

    const data = await response.json();

    if (!response.ok) {
      console.error("PayMongo checkout error:", JSON.stringify(data));
      return json({ error: data }, response.status);
    }

    const checkoutUrl = data.data.attributes.checkout_url;
    const sessionId = data.data.id;

    const { error: updateError } = await supabase
      .from("payment")
      .update({
        reference_number: sessionId,
        gateway_response: checkoutUrl,
      })
      .eq("order_id", orderIdNumber);

    if (updateError) {
      console.error("Failed to save session ID:", updateError);
      // Don't block the user: still return the URL, but log it.
    }

    return json({ checkoutUrl, sessionId }, 200);
  } catch (e) {
    console.error("create-checkout error:", e);
    // Don't leak internal error text to the client.
    return json({ error: "Could not start the payment. Please try again." }, 500);
  }
});