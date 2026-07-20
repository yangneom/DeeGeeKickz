// supabase/functions/ai-product-replacement/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_URL = "https://api.openai.com/v1/responses";

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
      `Search the web for ${brand}'s current sneaker lineup and suggest the closest ` +
      `current-generation replacement sneaker from the SAME brand (${brand}) that is ` +
      `still in production today. The store only carries these brands: ${JSON.stringify(availableBrands)} — ` +
      `only suggest a product from brand "${brand}" specifically. ` +
      `Respond with ONLY a JSON object, no markdown, no code fences, no extra sentences ` +
      `before or after the JSON: ` +
      `{"recommendedReplacement": "exact product name", "reasoning": "one sentence why"}`;

    const res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${OPENAI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-5.6",
        tools: [{ type: "web_search" }],
        input: prompt,
      }),
    });

    if (!res.ok) {
      const errText = await res.text();
      throw new Error(`OpenAI API error ${res.status}: ${errText}`);
    }

    const data = await res.json();

console.log("FULL OPENAI RESPONSE:", JSON.stringify(data)); // temporary debug

// Raw REST responses don't include the SDK's "output_text" convenience field —
// we have to walk the output array and find the actual message content.
let rawText = "";
if (Array.isArray(data.output)) {
  for (const item of data.output) {
    if (item.type === "message" && Array.isArray(item.content)) {
      for (const part of item.content) {
        if (part.type === "output_text" && part.text) {
          rawText += part.text;
        }
      }
    }
  }
}

console.log("EXTRACTED TEXT:", rawText);

const jsonMatch = rawText.match(/\{[\s\S]*\}/);
const cleaned = jsonMatch ? jsonMatch[0] : rawText.replace(/```json|```/g, "").trim();

let parsed;
try {
  parsed = JSON.parse(cleaned);
} catch {
  console.error("JSON parse failed. Cleaned text was:", cleaned);
  parsed = {
    recommendedReplacement: "Unable to determine",
    reasoning: "Could not parse a confident replacement from the model's response.",
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