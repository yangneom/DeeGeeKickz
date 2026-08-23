// ================================================
// EDGE FUNCTION: geocode-address
//
// Converts a text address into lat/lng using OpenCage. Called
// when a customer saves/edits an address in AddressBottomSheet.
//
// Output (success):
// {
//   "lat": 14.5578, "lng": 121.0192, "confidence": 8,
//   "formattedAddress": "...",
//   "locationMismatch": false   // true = "double check this on the map"
// }
// Output (no match at all): { "error": "No results found..." } (404)
// ================================================

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const OPENCAGE_API_KEY = Deno.env.get("OPENCAGE_API_KEY")!;

function cleanStreet(street: string): string {
  return street
    .replace(/\b(unit|rm|room|flr|floor|blk|block|lot)\.?\s*[\w-]+\s*,?/gi, "")
    .replace(/^[^,]*(?:condominium|condo|tower|building|bldg|residences|subdivision|subd\.?)[^,]*,\s*/i, "")
    .trim()
    .replace(/^,+|,+$/g, "")
    .trim();
}

async function queryOpenCage(query: string) {
  const url = new URL("https://api.opencagedata.com/geocode/v1/json");
  url.searchParams.set("q", query);
  url.searchParams.set("key", OPENCAGE_API_KEY);
  url.searchParams.set("countrycode", "ph");
  url.searchParams.set("limit", "1");
  url.searchParams.set("no_annotations", "1");

  const response = await fetch(url.toString());
  const json = await response.json();
  return { ok: response.ok, status: response.status, json };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { street, barangay, city, province, zipCode } = await req.json();

    const rawStreet = (street ?? "").toString().trim();
    const cleanedStreet = cleanStreet(rawStreet);

    const buildQuery = (streetPart: string) =>
      [streetPart, barangay, city, province, zipCode, "Philippines"]
        .filter((part) => part && part.toString().trim().length > 0)
        .join(", ");

    if (!buildQuery(rawStreet)) {
      return new Response(
        JSON.stringify({ error: "No address fields provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Attempt 1: cleaned street (strips unit/building noise).
    // Attempt 2 (fallback): raw street, in case cleaning stripped
    // something that was actually needed for a valid match.
    let query = buildQuery(cleanedStreet || rawStreet);
    let { ok, status, json } = await queryOpenCage(query);
    let result = json.results?.[0];

    if ((!ok || !result) && cleanedStreet && cleanedStreet !== rawStreet) {
      query = buildQuery(rawStreet);
      ({ ok, status, json } = await queryOpenCage(query));
      result = json.results?.[0];
    }

    if (!ok) {
      console.error("geocode-address: OpenCage error", status, json);
      return new Response(
        JSON.stringify({ error: "Geocoding service error", detail: json }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (!result) {
      return new Response(
        JSON.stringify({ error: "No results found for this address" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const MIN_USABLE_CONFIDENCE = 5;
    if (result.confidence < MIN_USABLE_CONFIDENCE) {
      console.warn("geocode-address: low-confidence match rejected", {
        query, confidence: result.confidence, formatted: result.formatted,
      });
      return new Response(
        JSON.stringify({
          error: "Address match too imprecise to use for delivery",
          confidence: result.confidence,
        }),
        { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Flag (don't block) if the matched city/province looks off from
    // what was typed. The frontend shows this as "please confirm the
    // pin" instead of us guessing wrong and hard-rejecting a real
    // address just because OpenCage's labeling doesn't line up
    // exactly with what the customer typed.
    const components = result.components ?? {};
    const matchedCity = (
      components.city || components.town || components.municipality || components.suburb || ""
    ).toString().toLowerCase();
    const matchedState = (components.state ?? "").toString().toLowerCase();
    const expectedCity = (city ?? "").toString().toLowerCase().trim();
    const expectedProvince = (province ?? "").toString().toLowerCase().trim();

        // If OpenCage gave us essentially nothing to check against (no
    // city/state info at all — just a bare postal-code-level match),
    // we can't verify it's right. Treat that as a mismatch rather
    // than letting an empty string trivially "pass" the check below.
    const hasLocalityInfo = matchedCity.length > 0 || matchedState.length > 0;

    const cityLooksRight =
      !expectedCity ||
      (hasLocalityInfo && (
        matchedCity.includes(expectedCity) ||
        expectedCity.includes(matchedCity) ||
        matchedState.includes(expectedCity) ||
        (expectedProvince && matchedState.includes(expectedProvince))
      ));

    if (!cityLooksRight) {
      console.warn("geocode-address: city mismatch — flagging for map confirmation", {
        query, expectedCity, expectedProvince, matchedCity, matchedState, formatted: result.formatted,
      });
    }

    return new Response(
      JSON.stringify({
        lat: result.geometry.lat,
        lng: result.geometry.lng,
        confidence: result.confidence,
        formattedAddress: result.formatted,
        locationMismatch: !cityLooksRight,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("geocode-address error:", error);
    return new Response(
      JSON.stringify({ error: "Internal error", detail: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});