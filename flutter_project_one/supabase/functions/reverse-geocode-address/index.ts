// ================================================
// EDGE FUNCTION: reverse-geocode-address
//
// Given lat/lng, returns what's actually there (if anything).
// Used by the map pin picker to warn the customer if they've
// dropped a pin somewhere with no real address (open water,
// empty land, etc.) before letting them confirm it.
//
// Input: { "lat": 14.55, "lng": 121.02 }
// Output: { "hasAddress": true, "formattedAddress": "..." }
//      or { "hasAddress": false }
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
    const { lat, lng } = await req.json();

    if (typeof lat !== "number" || typeof lng !== "number") {
      return new Response(
        JSON.stringify({ error: "lat and lng (numbers) are required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const url = new URL("https://api.opencagedata.com/geocode/v1/json");
    url.searchParams.set("q", `${lat},${lng}`);
    url.searchParams.set("key", OPENCAGE_API_KEY);
    url.searchParams.set("countrycode", "ph"); // PH-only, same as geocode-address
    url.searchParams.set("no_annotations", "1");
    url.searchParams.set("limit", "1");
    

    const response = await fetch(url.toString());
    const json = await response.json();

    if (!response.ok) {
      // Service hiccup — don't block the customer over a network
      // issue, just say we can't verify (frontend treats this as
      // "no warning shown", not "definitely empty").
      console.error("reverse-geocode-address: OpenCage error", response.status, json);
      return new Response(
        JSON.stringify({ hasAddress: true, formattedAddress: null }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

        const result = json.results?.[0];

    // No result at all (e.g. tapped somewhere outside the Philippines
    // entirely, now excluded by countrycode=ph) — definitely counts
    // as "no address here."
    if (!result) {
      return new Response(
        JSON.stringify({ hasAddress: false, formattedAddress: null }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const components = result.components ?? {};

    // "Has an address" = there's at least a city/town/suburb level
    // match. A bare country/ocean match doesn't count.
    const hasLocality = Boolean(
      components.city || components.town || components.municipality ||
      components.suburb || components.village,
    );

       // Returned so the Flutter side can detect a MISMATCH between the
    // pin's real location and whatever City/Barangay the customer
    // currently has selected — used to force re-confirmation rather
    // than silently saving stale text next to new coordinates.
    const detectedCity =
      components.city || components.town || components.municipality || null;
    const detectedBarangay =
      components.suburb || components.village || components.neighbourhood || null;

    return new Response(
      JSON.stringify({
        hasAddress: hasLocality,
        formattedAddress: result?.formatted ?? null,
        detectedCity,
        detectedBarangay,
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (error) {
    console.error("reverse-geocode-address error:", error);
    // Same philosophy — a server error shouldn't block the customer,
    // just skip the warning.
    return new Response(
      JSON.stringify({ hasAddress: true, formattedAddress: null }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});