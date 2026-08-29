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
  // FIX #7: the old version only stripped a building/condo name when
  // it was the FIRST comma-segment ("One Wilson Place Condominium,
  // Wilson St"). A customer typing it the other way ("123 Wilson St,
  // One Wilson Place Condominium") kept the ambiguous building name
  // in the query untouched. Splitting into segments and filtering
  // catches it regardless of position.
  const buildingKeywordPattern =
    /\b(condominium|condo|tower|building|bldg|residences|subdivision|subd\.?)\b/i;
  // Purok and Phase are Philippine internal cluster/subdivision-phase
  // markers, same category of noise as Unit/Blk/Lot — arbitrary local
  // numbering that means nothing to a geocoder and can accidentally
  // match an unrelated "Phase X" or named area somewhere else in the
  // country.
  const unitPattern = /\b(unit|rm|room|flr|floor|blk|block|lot|purok|phase)\.?\s*[\w-]+/gi;

  const segments = street
    .split(",")
    .map((seg) => seg.trim())
    .filter((seg) => seg.length > 0 && !buildingKeywordPattern.test(seg));

  return segments
    .map((seg) => seg.replace(unitPattern, "").trim())
    .filter((seg) => seg.length > 0)
    .join(", ");
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
    // FIX #9: suburb removed from this fallback chain — it's used
    // below as the barangay-level signal instead. Letting the same
    // field serve as both "matched city" and "matched barangay"
    // meant the barangay check could just be echoing the city check
    // back at itself instead of confirming anything independently.
    const matchedCity = (
      components.city || components.town || components.municipality || ""
    ).toString().toLowerCase();
    const matchedState = (components.state ?? "").toString().toLowerCase();
    const expectedCity = (city ?? "").toString().toLowerCase().trim();
    const expectedProvince = (province ?? "").toString().toLowerCase().trim();

    // If OpenCage gave us essentially nothing to check against (no
    // city/state info at all — just a bare postal-code-level match),
    // we can't verify it's right. Treat that as a mismatch rather
    // than letting an empty string trivially "pass" the check below.
    const hasLocalityInfo = matchedCity.length > 0 || matchedState.length > 0;

    // FIX: previously, a missing `city` field made this check
    // automatically pass (!expectedCity === true short-circuited to
    // "looks right"). That's backwards — no city to compare against
    // means we can't verify anything, which should be treated as
    // suspicious, not as a free pass.
    // FIX #12: matchedCity.includes(expectedCity) is already safe (an
    // empty matchedCity can never "contain" a non-empty expectedCity).
    // But expectedCity.includes(matchedCity) is NOT safe on its own —
    // in JS, "anything".includes("") is always true, so an empty
    // matchedCity used to make this whole check silently pass no
    // matter what matchedState said. Guarding it with a length check
    // closes that loophole.
    const cityLooksRight =
      Boolean(expectedCity) &&
      hasLocalityInfo &&
      (matchedCity.includes(expectedCity) ||
        (matchedCity.length > 0 && expectedCity.includes(matchedCity)) ||
        matchedState.includes(expectedCity) ||
        (expectedProvince && matchedState.includes(expectedProvince)));

    // FIX: same-city errors (e.g. Camarin vs Grace Park, both
    // "Caloocan") were slipping through undetected because the check
    // above only looks at city level. Large cities like Caloocan,
    // Quezon City, and Manila span genuinely distant districts, so
    // also compare barangay against whatever finer-grained field
    // OpenCage returns — the exact field name varies by area.
    const matchedBarangay = (
      components.suburb || components.neighbourhood ||
      components.quarter || components.city_district || ""
    ).toString().toLowerCase();
    const expectedBarangay = (barangay ?? "").toString().toLowerCase().trim();

    // Skip this specific check if OpenCage gave us nothing to compare
    // against (some areas just don't have barangay-level OSM data) —
    // no data to check against isn't the same as a confirmed mismatch,
    // so this one doesn't need the same "empty = suspicious" treatment
    // as city above.
    const barangayLooksRight =
      !expectedBarangay ||
      !matchedBarangay ||
      matchedBarangay.includes(expectedBarangay) ||
      expectedBarangay.includes(matchedBarangay);

       const locationMismatch = !cityLooksRight || !barangayLooksRight;

    if (!cityLooksRight) {
      console.warn("geocode-address: city mismatch, flagging for map confirmation", {
        query, expectedCity, expectedProvince, matchedCity, matchedState, formatted: result.formatted,
      });
    }
    if (!barangayLooksRight) {
      console.warn("geocode-address: barangay mismatch, flagging for map confirmation", {
        query, expectedBarangay, matchedBarangay, formatted: result.formatted,
      });
    }

    // Locality-anchored fallback. Now that Region/Province/City/
    // Barangay come from verified PSGC selections (not free text),
    // a mismatch here can no longer mean "customer typo'd the city"
    // — it means the full-address match (heavily influenced by the
    // free-text street) landed somewhere untrustworthy. Rather than
    // hand back that wild point, re-query using ONLY the confirmed
    // locality fields and use that as the starting pin instead — at
    // least placing the customer inside the correct barangay to
    // fine-tune manually, instead of in open water or another province.
    let usedLocalityFallback = false;

    if (locationMismatch) {
      const localityQuery = [barangay, city, province, "Philippines"]
        .filter((part) => part && part.toString().trim().length > 0)
        .join(", ");

      if (localityQuery) {
        const fallback = await queryOpenCage(localityQuery);
        const fallbackResult = fallback.json.results?.[0];

        if (fallback.ok && fallbackResult) {
          const fbComponents = fallbackResult.components ?? {};
          const fbMatchedCity = (
            fbComponents.city || fbComponents.town || fbComponents.municipality || ""
          ).toString().toLowerCase();
          const fbMatchedState = (fbComponents.state ?? "").toString().toLowerCase();

          const fbCityLooksRight =
            Boolean(expectedCity) &&
            (fbMatchedCity.length > 0 || fbMatchedState.length > 0) &&
            (fbMatchedCity.includes(expectedCity) ||
              (fbMatchedCity.length > 0 && expectedCity.includes(fbMatchedCity)) ||
              fbMatchedState.includes(expectedCity) ||
              (expectedProvince && fbMatchedState.includes(expectedProvince)));

          if (fbCityLooksRight) {
            result = fallbackResult;
            usedLocalityFallback = true;
            console.warn("geocode-address: full-address match rejected, using locality-level anchor instead", {
              query, localityQuery, formatted: fallbackResult.formatted,
            });
          }
        }
      }
    }

    return new Response(
      JSON.stringify({
        lat: result.geometry.lat,
        lng: result.geometry.lng,
        confidence: result.confidence,
        formattedAddress: result.formatted,
        locationMismatch: locationMismatch,
        localityAnchorOnly: usedLocalityFallback,
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