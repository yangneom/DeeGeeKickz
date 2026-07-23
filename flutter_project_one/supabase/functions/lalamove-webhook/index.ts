// ================================================
// EDGE FUNCTION: lalamove-webhook
//
// Lalamove calls THIS endpoint automatically whenever a booked
// order's status changes (driver assigned, picked up, completed,
// cancelled, etc). This is what makes tracking automatic — no
// admin action needed after the order is booked.
//
// One-time setup (not code — done once in the Partner Portal):
//   Developers tab -> Webhook -> paste this function's public URL,
//   e.g. https://<your-project-ref>.supabase.co/functions/v1/lalamove-webhook
//
// Must respond 200 quickly or Lalamove will retry/flag the webhook
// as broken — so this just writes to the DB and returns, no slow work.
//
// NOTE: This does NOT verify a Lalamove signature on the incoming
// webhook yet — Lalamove's webhook payloads don't carry the same
// HMAC used for outbound calls. If Lalamove's dashboard exposes a
// webhook signing secret, add verification here before trusting the
// body in production.
// ================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/lalamove.ts";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, // service role — bypasses RLS, needed for a webhook with no user session
);

// Map Lalamove order status -> your internal order_status vocabulary
function mapStatus(lalamoveStatus: string): string | null {
  switch (lalamoveStatus) {
    case "ASSIGNING_DRIVER":
    case "ON_GOING":
      return "Shipped";
    case "PICKED_UP":
      return "Shipped";
    case "COMPLETED":
      return "Delivered";
    case "CANCELED":
    case "REJECTED":
    case "EXPIRED":
      return "Cancelled";
    default:
      return null; // unknown/irrelevant event — don't overwrite status
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();

    // Lalamove webhook payloads are wrapped like { data: { ... } }
    const data = payload.data ?? payload;
    const lalamoveOrderId: string | undefined = data.order?.orderId ?? data.orderId;
    const lalamoveStatus: string | undefined = data.order?.status ?? data.status;
    const shareLink: string | undefined = data.order?.shareLink ?? data.shareLink;

    if (!lalamoveOrderId) {
      console.warn("lalamove-webhook: payload missing orderId", payload);
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    // Find your internal order by the Lalamove order id we stored
    // when create-delivery-order ran (see lalamove_order_id column).
    const { data: orderRow, error: findError } = await supabase
      .from("orders")
      .select("order_id, order_status")
      .eq("lalamove_order_id", lalamoveOrderId)
      .maybeSingle();

    if (findError || !orderRow) {
      console.warn(
        "lalamove-webhook: no matching order for lalamoveOrderId",
        lalamoveOrderId,
        findError,
      );
      return new Response(JSON.stringify({ received: true }), { status: 200 });
    }

    const mappedStatus = lalamoveStatus ? mapStatus(lalamoveStatus) : null;

    const updatePayload: Record<string, unknown> = {};
    if (shareLink) updatePayload.tracking_url = shareLink;
    if (mappedStatus && mappedStatus !== orderRow.order_status) {
      updatePayload.order_status = mappedStatus;
    }

    if (Object.keys(updatePayload).length > 0) {
      await supabase
        .from("orders")
        .update(updatePayload)
        .eq("order_id", orderRow.order_id);
    }

    if (mappedStatus && mappedStatus !== orderRow.order_status) {
      await supabase.from("order_progress").insert({
        order_id: orderRow.order_id,
        status: mappedStatus,
        admin_note: `Auto-updated from Lalamove (${lalamoveStatus}).`,
      });
    }

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("lalamove-webhook error:", error);
    // Still return 200 — Lalamove will keep retrying otherwise, and a
    // malformed/unexpected payload shouldn't cause a retry storm.
    return new Response(JSON.stringify({ received: true, error: String(error) }), {
      status: 200,
    });
  }
});