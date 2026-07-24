// ================================================
// EDGE FUNCTION: get-delivery-quote
//
// Called from the Flutter app at checkout (Step 1 —
// after the customer picks/confirms a shipping address).
//
// Input (POST body):
// {
//   "pickup":  { "lat": 14.5995, "lng": 120.9842 },
//   "dropoff": { "lat": 14.6091, "lng": 121.0223, "address": "123 Foo St, Makati" },
//   "serviceType": "MOTORCYCLE"   // optional, defaults below
// }
//
// Output:
// {
//   "quotationId": "...",
//   "priceTotal": 125.00,
//   "currency": "PHP",
//   "distanceKm": 5.4,
//   "stops": [ { "stopId": "...", ... }, ... ]  // needed later for /v3/orders
// }
//
// Note: this quotation is NOT booking a courier — it's just a
// price + a quotationId that stays valid for a few minutes.
// The actual order is booked later via create-delivery-order,
// when admin marks the order "Shipped".
// ================================================

import { callLalamove, corsHeaders } from "../_shared/lalamove.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { pickup, dropoff, serviceType, item } = await req.json();

    if (!pickup?.lat || !pickup?.lng || !dropoff?.lat || !dropoff?.lng) {
      return new Response(
        JSON.stringify({
          error: "pickup and dropoff must each include lat and lng",
        }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const requestBody = {
      data: {
        serviceType: serviceType ?? "MOTORCYCLE",
        language: "en_PH",
        stops: [
          {
            coordinates: {
              lat: pickup.lat.toString(),
              lng: pickup.lng.toString(),
            },
            address: pickup.address ?? "Store pickup location",
          },
          {
            coordinates: {
              lat: dropoff.lat.toString(),
              lng: dropoff.lng.toString(),
            },
            address: dropoff.address ?? "Customer delivery address",
          },
        ],
        item: {
          quantity: (item?.quantity ?? "1").toString(),
          weight: item?.weight ?? "LESS_THAN_3_KG",
          categories: item?.categories ?? ["OTHERS"],
          handlingInstructions: [],
        },
      },
    };

    const { ok, status, json } = await callLalamove({
      method: "POST",
      path: "/v3/quotations",
      body: requestBody,
    });

    if (!ok) {
      console.error("Lalamove quotation error:", status, json);
      return new Response(
        JSON.stringify({
          error: "Failed to get delivery quote from Lalamove",
          detail: json,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const data = json.data;

    return new Response(
      JSON.stringify({
        quotationId: data.quotationId,
        priceTotal: parseFloat(data.priceBreakdown?.total ?? "0"),
        currency: data.priceBreakdown?.currency ?? "PHP",
        stops: data.stops, // keep stopIds — needed for /v3/orders later
        expiresAt: data.expiresAt,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("get-delivery-quote error:", error);
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});