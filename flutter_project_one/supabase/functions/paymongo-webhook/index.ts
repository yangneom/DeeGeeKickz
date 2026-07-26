import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  try {
    const rawBody = await req.text();
    const webhookSecret = Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "";

    // Verify the webhook signature from PayMongo
    const sigHeader = req.headers.get("paymongo-signature") ?? "";
    const parts = Object.fromEntries(
      sigHeader.split(",").map((p) => p.split("="))
    );
    const timestamp = parts["t"];
    const signature = parts["te"] ?? parts["li"];

    const toSign = `${timestamp}.${rawBody}`;
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(webhookSecret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sigBytes = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(toSign)
    );
    const computed = Array.from(new Uint8Array(sigBytes))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (computed !== signature) {
      console.error("Signature mismatch — computed:", computed, "received:", signature);
      return new Response("Unauthorized", { status: 401 });
    }

    const payload = JSON.parse(rawBody);
    const eventType = payload?.data?.attributes?.type;

    if (eventType !== "checkout_session.payment.paid") {
      return new Response("OK", { status: 200 });
    }

    const attributes = payload.data.attributes.data?.attributes;
    const payments = attributes?.payments ?? [];
    const paymentId = payments[0]?.id ?? null;
    const sessionId = payload.data.attributes.data?.id ?? null;

    if (!paymentId || !sessionId) {
      console.error("Missing paymentId or sessionId", { paymentId, sessionId });
      return new Response("Missing IDs", { status: 400 });
    }

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // Find payment row by session ID
    const { data: paymentRow, error: findError } = await supabase
      .from("payment")
      .select("payment_id, order_id")
      .eq("reference_number", sessionId)
      .single();

    if (findError || !paymentRow) {
      console.error("Payment row not found for session:", sessionId, findError);
      return new Response("Not found", { status: 404 });
    }

    // Walk-in QR sales (order_type = 'In-Store') skip admin approval
    // entirely and complete immediately with stock deducted. Normal
    // online orders keep going to 'Pending' for the admin to approve.
    const { data: orderRow, error: orderFetchError } = await supabase
      .from("orders")
      .select("order_type, order_status")
      .eq("order_id", paymentRow.order_id)
      .single();

    if (orderFetchError || !orderRow) {
      console.error("Failed to fetch order:", orderFetchError);
      return new Response("DB error", { status: 500 });
    }

    // IDEMPOTENCY GUARD: payment gateways routinely redeliver the same
    // webhook event (timeouts, retry policies, etc.) — this is normal,
    // expected behavior, not an edge case. If this order has already
    // moved past 'Awaiting Payment', every side effect below (stock
    // deduction, payment_status, order_progress log) has already run
    // for this order. Re-running stock deduction on a duplicate
    // delivery would silently deduct real stock_quantity a second
    // time for a single sale. Bail out here, before touching payment
    // or stock at all.
    if (orderRow.order_status !== "Awaiting Payment") {
      console.log(
        `Duplicate webhook delivery ignored — order ${paymentRow.order_id} ` +
        `already at status '${orderRow.order_status}'.`
      );
      return new Response("OK (already processed)", { status: 200 });
    }

    // NOTE: This only marks the gateway confirmation as "Verified", not
    // "Paid". 'Paid' is reserved exclusively for a sale that has actually
    // been finalized — for In-Store walk-in QR sales that happens
    // immediately below (no approval step), but for Online orders it only
    // happens once admin clicks "Approve Payment" in the admin dashboard.
    // This keeps payment_status = 'Paid' unambiguous everywhere in the
    // app: it always means "this is a real, finalized sale."
    const { error: updateError } = await supabase
      .from("payment")
      .update({
        reference_number: paymentId,
        payment_status:   "Verified",
        payment_date:     new Date().toISOString(),
      })
      .eq("payment_id", paymentRow.payment_id);

    if (updateError) {
      console.error("Failed to update payment:", updateError);
      return new Response("DB error", { status: 500 });
    }

    if (orderRow.order_type === "In-Store") {
      const { data: orderItems, error: itemsError } = await supabase
        .from("order_item")
        .select("size_id, quantity")
        .eq("order_id", paymentRow.order_id);

      if (itemsError) {
        console.error("Failed to fetch order_item:", itemsError);
        return new Response("DB error", { status: 500 });
      }

      for (const item of orderItems ?? []) {
        if (item.size_id == null) continue;

        const { data: sizeRow, error: sizeError } = await supabase
          .from("product_variant_size")
          .select("stock_quantity, reserved_quantity")
          .eq("size_id", item.size_id)
          .single();

        if (sizeError || !sizeRow) {
          console.error("Failed to fetch product_variant_size:", sizeError);
          continue;
        }

        const newStock = (sizeRow.stock_quantity ?? 0) - item.quantity;
        const newReserved = Math.max(
          0,
          (sizeRow.reserved_quantity ?? 0) - item.quantity
        );

        await supabase
          .from("product_variant_size")
          .update({ stock_quantity: newStock, reserved_quantity: newReserved })
          .eq("size_id", item.size_id);
      }

      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({ order_status: "Completed" })
        .eq("order_id", paymentRow.order_id)
        .eq("order_status", "Awaiting Payment");

      if (orderUpdateError) {
        console.error("Failed to update order status:", orderUpdateError);
        return new Response("DB error", { status: 500 });
      }

      // In-Store walk-in QR sales finalize immediately — no admin
      // approval step exists for them, so this is the only place
      // payment_status becomes 'Paid' for this order type.
      const { error: paidUpdateError } = await supabase
        .from("payment")
        .update({ payment_status: "Paid" })
        .eq("payment_id", paymentRow.payment_id);

      if (paidUpdateError) {
        console.error("Failed to mark In-Store payment Paid:", paidUpdateError);
        return new Response("DB error", { status: 500 });
      }

      await supabase.from("order_progress").insert({
        order_id:   paymentRow.order_id,
        status:     "Completed",
        admin_note: "In-store QR payment confirmed — stock committed automatically.",
      });
    } else {
      const { error: orderUpdateError } = await supabase
        .from("orders")
        .update({ order_status: "Pending" })
        .eq("order_id", paymentRow.order_id)
        .eq("order_status", "Awaiting Payment");

      if (orderUpdateError) {
        console.error("Failed to update order status:", orderUpdateError);
        return new Response("DB error", { status: 500 });
      }

      await supabase.from("order_progress").insert({
        order_id:   paymentRow.order_id,
        status:     "Pending",
        admin_note: "GCash payment confirmed via webhook — awaiting admin approval.",
      });
    }

    console.log(`Payment confirmed: order ${paymentRow.order_id} → ${paymentId}`);
    return new Response("OK", { status: 200 });

  } catch (err) {
    console.error("Webhook error:", err);
    return new Response("Error", { status: 500 });
  }
});