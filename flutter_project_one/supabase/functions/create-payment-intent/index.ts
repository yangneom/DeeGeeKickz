 
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
        const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { createClient } = await import("https://esm.sh/@supabase/supabase-js@2");
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    const { data: { user } } = await supabase.auth.getUser(authHeader.replace("Bearer ", ""));
    if (!user) {
      return new Response(JSON.stringify({ error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const { orderId, customerName, customerEmail, cardNumber, expMonth, expYear, cvc, cardHolder } = await req.json();

    // Fetch the REAL order — ownership check + true amount, both from
    // the server's own data, never trusting whatever the client sends.
    const { data: orderRow, error: orderError } = await supabase
      .from("orders")
      .select("user_id, total_amount, order_status")
      .eq("order_id", orderId)
      .single();

    if (orderError || !orderRow) {
      return new Response(JSON.stringify({ error: "Order not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (orderRow.user_id !== user.id) {
      return new Response(JSON.stringify({ error: "Forbidden" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    if (orderRow.order_status !== "Awaiting Payment") {
      return new Response(JSON.stringify({ error: "This order is not awaiting payment" }),
        { status: 409, headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    const amount = orderRow.total_amount; // server's number, not the client's

        const secretKey = Deno.env.get("PAYMONGO_SECRET_KEY") ?? "";
    const paymongoAuthHeader = `Basic ${btoa(secretKey + ":")}`;
    const amountInCentavos = Math.round(amount * 100);

    // Step 1: Create Payment Intent
    const intentRes = await fetch(
      "https://api.paymongo.com/v1/payment_intents",
      {
        method: "POST",
           headers: { "Content-Type": "application/json", "Authorization": paymongoAuthHeader },
        body: JSON.stringify({
          data: {
            attributes: {
              amount:                 amountInCentavos,
              payment_method_types:   ["card"],
              payment_method_allowed: ["card"],
              currency:               "PHP",
              capture_type:           "automatic",
              description:            `Order #${orderId} — DeeGee Kickz`,
            },
          },
        }),
      }
    );
    const intentData = await intentRes.json();
    if (!intentRes.ok) {
      console.error("PayMongo Intent Error:", JSON.stringify(intentData));
      return new Response(JSON.stringify({ error: intentData }), {
        status: intentRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const intentId  = intentData.data.id;
    const clientKey = intentData.data.attributes.client_key;

    // Step 2: Create Payment Method
    const methodRes = await fetch(
      "https://api.paymongo.com/v1/payment_methods",
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": authHeader },
        body: JSON.stringify({
          data: {
            attributes: {
              type: "card",
              details: {
                card_number: cardNumber,
                exp_month:   parseInt(expMonth),
                exp_year:    parseInt(expYear),
                cvc:         cvc,
              },
              billing: {
                name:  cardHolder || customerName,
                email: customerEmail,
              },
            },
          },
        }),
      }
    );
    const methodData = await methodRes.json();
    if (!methodRes.ok) {
      console.error("PayMongo Method Error:", JSON.stringify(methodData));
      return new Response(JSON.stringify({ error: methodData?.errors?.[0] ?? methodData }), {
        status: methodRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }
    const methodId = methodData.data.id;

    // Step 3: Attach Payment Method to Intent
    const attachRes = await fetch(
      `https://api.paymongo.com/v1/payment_intents/${intentId}/attach`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json", "Authorization": authHeader },
        body: JSON.stringify({
          data: {
            attributes: {
              payment_method:         methodId,
              client_key:             clientKey,
              payment_method_allowed: ["card"],
              return_url:             `https://dgeekickz.com/payment-success?order=${orderId}`,
            },
          },
        }),
      }
    );
    const attachData = await attachRes.json();
    if (!attachRes.ok) {
      console.error("PayMongo Attach Error:", JSON.stringify(attachData));
      return new Response(JSON.stringify({ error: attachData?.errors?.[0] ?? attachData }), {
        status: attachRes.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const status    = attachData.data.attributes.status;
    const paymentId = attachData.data.attributes.payments?.[0]?.id ?? null;

    // Step 4: Update DB if payment succeeded
    // NOTE: Card orders go through the same admin approval flow as
    // GCash — the gateway confirming the charge is not the same as
    // this being a finalized sale. payment_status is set to
    // 'Verified' here (gateway-confirmed, awaiting admin review), and
    // only becomes 'Paid' once admin clicks "Approve Payment" in the
    // admin dashboard (see PaymentService.approvePayment()).
      if (status === "succeeded" || status === "paid") {
      await supabase.from("payment").update({
        payment_status:   "Verified",
        reference_number: paymentId ?? intentId,
        payment_date:     new Date().toISOString(),
      }).eq("order_id", orderId);

      await supabase.from("orders").update({ order_status: "Pending" })
        .eq("order_id", orderId)
        .eq("order_status", "Awaiting Payment");

      await supabase.from("order_progress").insert({
        order_id:   orderId,
        status:     "Pending",
        admin_note: "Card payment confirmed via Payment Intents — awaiting admin approval.",
      });
    }

    return new Response(JSON.stringify({ status, intentId, paymentId }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});