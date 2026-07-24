// ================================================
// EDGE FUNCTION: create-delivery-order
//
// Called from the ADMIN app when marking an order "Shipped".
// Replaces the old manual "paste tracking link" step.
//
// Because Lalamove quotations expire after a few minutes, this
// function gets a FRESH quotation first, then immediately places
// the order with that quotation's ID — all in one call, so the
// admin just clicks one button and gets back a real tracking link.
//
// Input (POST body):
// {
//   "orderId": 123,                 // your internal order_id, for logging only
//   "pickup":  { "lat": .., "lng": .., "address": "Store address" },
//   "dropoff": { "lat": .., "lng": .., "address": "Customer address" },
//   "sender":    { "name": "DeeGee Kickz", "phone": "+639171234567" },
//   "recipient": { "name": "Juan Dela Cruz", "phone": "+639181234567" },
//   "serviceType": "MOTORCYCLE"      // optional
// }
//
// Output:
// {
//   "lalamoveOrderId": "...",
//   "trackingUrl": "...",           // ShareLink — save this to orders.tracking_url
//   "priceTotal": 130.00,
//   "status": "ASSIGNING_DRIVER"
// }
// ================================================

import { callLalamove, corsHeaders } from "../_shared/lalamove.ts";

// ================================================
// PH PHONE NORMALIZATION
// Lalamove requires E.164 format (+639171234567), but numbers in
// the DB are typically stored in local format (09171234567) or
// with stray spaces/dashes. This converts common PH formats to
// E.164 without needing every caller to get this right themselves.
// ================================================
function normalizePhPhone(raw: string): string {
  const digits = raw.replace(/[^\d+]/g, ""); // strip spaces, dashes, parens

  if (digits.startsWith("+63")) return digits;
  if (digits.startsWith("63")) return `+${digits}`;
  if (digits.startsWith("0")) return `+63${digits.slice(1)}`;
  // Fallback — assume it's a 10-digit local number missing the leading 0
  if (digits.length === 10) return `+63${digits}`;

  return digits; // last resort — send as-is, Lalamove will reject if invalid
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const {
      orderId,
      pickup,
      dropoff,
      sender,
      recipient,
      serviceType,
      item,
    } = await req.json();

    if (
      !pickup?.lat || !pickup?.lng ||
      !dropoff?.lat || !dropoff?.lng ||
      !sender?.phone || !recipient?.phone
    ) {
      return new Response(
        JSON.stringify({
          error:
            "pickup and dropoff must each include lat and lng, and sender/recipient must include phone",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // ── Step 1: fresh quotation (required — old quotationId from
    //    checkout time has almost certainly expired by now) ──
    const quotationBody = {
      data: {
        serviceType: serviceType ?? "MOTORCYCLE",
        language: "en_PH",
        stops: [
          {
            coordinates: { lat: pickup.lat.toString(), lng: pickup.lng.toString() },
            address: pickup.address ?? "Store pickup location",
          },
          {
            coordinates: { lat: dropoff.lat.toString(), lng: dropoff.lng.toString() },
            address: dropoff.address ?? "Customer delivery address",
          },
        ],
       item: {
          quantity: (item?.quantity ?? "1").toString(),
          weight: item?.weight ?? "LESS_THAN_3_KG",
          // NOTE: verify these category values against Lalamove's
          // current /v3 category enum for your market — do not
          // assume "OTHERS" or the old "FOOD_DELIVERY" is correct.
          categories: item?.categories ?? ["OTHERS"],
          handlingInstructions: [],
        },
      },
    };

    const quoteResult = await callLalamove({
      method: "POST",
      path: "/v3/quotations",
      body: quotationBody,
    });

    if (!quoteResult.ok) {
      console.error("create-delivery-order: quotation failed", quoteResult.json);
      return new Response(
        JSON.stringify({
          error: "Could not get a fresh quotation before booking",
          detail: quoteResult.json,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const quotation = quoteResult.json.data;
    const pickupStopId = quotation.stops[0].stopId;
    const dropoffStopId = quotation.stops[1].stopId;

    // ── Step 2: place the actual order using that quotation ──
    const orderBody = {
      data: {
        quotationId: quotation.quotationId,
        sender: {
          stopId: pickupStopId,
          name: sender.name ?? "Store",
          phone: normalizePhPhone(sender.phone),
        },
        recipients: [
          {
            stopId: dropoffStopId,
            name: recipient.name ?? "Customer",
            phone: normalizePhPhone(recipient.phone),
          },
        ],
        isPODEnabled: true, // proof of delivery (photo) on completion
        metadata: {
          internalOrderId: (orderId ?? "").toString(),
        },
      },
    };

    const orderResult = await callLalamove({
      method: "POST",
      path: "/v3/orders",
      body: orderBody,
    });

    if (!orderResult.ok) {
      console.error("create-delivery-order: order placement failed", orderResult.json);
      return new Response(
        JSON.stringify({
          error: "Could not place the Lalamove order",
          detail: orderResult.json,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const order = orderResult.json.data;

    return new Response(
      JSON.stringify({
        lalamoveOrderId: order.orderId,
        trackingUrl: order.shareLink,
        priceTotal: parseFloat(order.priceBreakdown?.total ?? "0"),
        status: order.status,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("create-delivery-order error:", error);
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});