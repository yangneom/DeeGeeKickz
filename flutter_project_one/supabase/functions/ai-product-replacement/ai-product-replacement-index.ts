// supabase/functions/ai-product-replacement/index.ts
//
// Uses Gemini with Google Search grounding to find a real,
// currently-available replacement for a discontinued/archived
// product, restricted to the store's existing brand lineup.
//
// POST body: { discontinuedProduct: string, brand: string, availableBrands: string[] }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY")!;
const GEMINI_URL =
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${GEMINI_API_KEY}`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { discontinuedProduct, brand, availableBrands } = await req.json();

    if (!discontinuedProduct || !brand) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing discontinuedProduct or brand" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const prompt =
      `A sneaker retailer has discontinued "${discontinuedProduct}" (brand: ${brand}). ` +
      `Search the web for the closest current-generation replacement sneaker from ` +
      `the SAME brand (${brand}) that is still in production and available to buy today. ` +
      `The store only carries these brands: ${JSON.stringify(availableBrands)} — ` +
      `only suggest a product from brand "${brand}" specifically. ` +
      `Respond with ONLY a JSON object, no markdown, no code fences: ` +
      `{"recommendedReplacement": "exact product name", "reasoning": "one sentence why"}`;

    const res = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
        generationConfig: { temperature: 0.2 },
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`Gemini API error ${res.status}: ${errText}`);
    }

    const data = await res.json();
    const rawText: string =
      data.candidates?.[0]?.content?.parts?.map((p: any) => p.text || "").join("") ?? "";

    // Strip markdown fences if Gemini wrapped the JSON anyway
    const cleaned = rawText.replace(/```json|```/g, "").trim();

    let parsed;
    try {
      parsed = JSON.parse(cleaned);
    } catch {
      // Fall back to a safe shape if Gemini didn't return clean JSON
      parsed = {
        recommendedReplacement: "Unable to determine",
        reasoning: "Could not parse a confident replacement from search results.",
      };
    }

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          discontinuedProduct,
          brand,
          recommendedReplacement: parsed.recommendedReplacement,
          reasoning: parsed.reasoning,
        },
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("ai-product-replacement error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});