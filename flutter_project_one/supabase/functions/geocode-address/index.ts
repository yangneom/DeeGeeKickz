// ================================================
// EDGE FUNCTION: geocode-address
//
// Converts a text address (street, barangay, city, province,
// zip) into lat/lng coordinates using OpenCage. Called once,
// when a customer saves/edits an address in AddressBottomSheet
// — NOT on every checkout, so this stays well within OpenCage's
// free tier (2,500 requests/day).
//
// Input (POST body):
// {
//   "street": "123 Foo St",
//   "barangay": "Bel-Air",
//   "city": "Makati",
//   "province": "Metro Manila",
//   "zipCode": "1200"
// }
//
// Output (success):
// {
//   "lat": 14.5578,
//   "lng": 121.0192,
//   "confidence": 8,          // 1 (worst) - 10 (best), per OpenCage docs
//   "formattedAddress": "123 Foo St, Bel-Air, Makati, Metro Manila, Philippines"
// }
//
// Output (no match found):
// { "error": "No results found for this address" }   (404)
// ================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENCAGE_API_KEY = Deno.env.get("OPENCAGE_API_KEY")!;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { street, barangay, city, province, zipCode } = await req.json();

    // Build one query string from whichever parts were provided —
    // more specific parts first improves match accuracy.
    const addressParts = [street, barangay, city, province, zipCode, "Philippines"]
      .filter((part) => part && part.toString().trim().length > 0);

    if (addressParts.length === 0) {
      return new Response(
        JSON.stringify({ error: "No address fields provided" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const query = addressParts.join(", ");

    const url = new URL("https://api.opencagedata.com/geocode/v1/json");
    url.searchParams.set("q", query);
    url.searchParams.set("key", OPENCAGE_API_KEY);
    url.searchParams.set("countrycode", "ph"); // restrict results to the Philippines
    url.searchParams.set("limit", "1");
    url.searchParams.set("no_annotations", "1"); // trims the response, we don't need timezone/currency etc

    const response = await fetch(url.toString());
    const json = await response.json();

    if (!response.ok) {
      console.error("geocode-address: OpenCage error", response.status, json);
      return new Response(
        JSON.stringify({ error: "Geocoding service error", detail: json }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

const result = json.results?.[0];

    if (!result) {
      return new Response(
        JSON.stringify({ error: "No results found for this address" }),
        {
          status: 404,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    // OpenCage confidence: 10 = accurate to ~0.25km, 1 = accurate to
    // 750km+. Below this threshold the "match" is often just a city
    // or province centroid — technically a coordinate, but useless
    // (and misleading) for actually routing a courier there. Treat
    // it the same as "no results" so the app falls back to manual
    // tracking instead of silently booking against a fake point.
    const MIN_USABLE_CONFIDENCE = 5;

    if (result.confidence < MIN_USABLE_CONFIDENCE) {
      console.warn(
        "geocode-address: low-confidence match rejected",
        { query, confidence: result.confidence, formatted: result.formatted },
      );
      return new Response(
        JSON.stringify({
          error: "Address match too imprecise to use for delivery",
          confidence: result.confidence,
        }),
        {
          status: 422,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    return new Response(
      JSON.stringify({
        lat: result.geometry.lat,
        lng: result.geometry.lng,
        confidence: result.confidence,
        formattedAddress: result.formatted,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("geocode-address error:", error);
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});