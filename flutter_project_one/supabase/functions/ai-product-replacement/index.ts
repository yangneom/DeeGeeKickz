// supabase/functions/ai-product-replacement/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_URL = "https://api.openai.com/v1/responses";
const MODEL = "gpt-5.6-luna";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // once per day, per product, per mode
const FORCE_REFRESH_COOLDOWN_MS = 5 * 60 * 1000; // 5 minutes between forced refreshes

const BRAND_DOMAINS: Record<string, string[]> = {
  Nike: ["nike.com"],
  Adidas: ["adidas.com"],
  Puma: ["puma.com"],
  "New Balance": ["newbalance.com"],
  Converse: ["converse.com"],
  Vans: ["vans.com"],
  Reebok: ["reebok.com"],
  "Under Armour": ["underarmour.com"],
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

async function getCached(cacheKey: string) {
  const { data } = await supabase
    .from("ai_dashboard_cache")
    .select("result_json, generated_at")
    .eq("cache_key", cacheKey)
    .maybeSingle();

  if (data) {
    const age = Date.now() - new Date(data.generated_at).getTime();
    if (age < CACHE_TTL_MS) return data.result_json;
  }
  return null;
}

// Separate from getCached — returns the last-generated timestamp
// regardless of whether it's within the normal 24h TTL, so a
// forceRefresh request can be cooldown-checked even after the
// entry has technically expired.
async function getLastGeneratedAt(cacheKey: string): Promise<number | null> {
  const { data } = await supabase
    .from("ai_dashboard_cache")
    .select("generated_at")
    .eq("cache_key", cacheKey)
    .maybeSingle();

  return data ? new Date(data.generated_at).getTime() : null;
}

async function setCached(cacheKey: string, value: unknown) {
  await supabase.from("ai_dashboard_cache").upsert({
    cache_key: cacheKey,
    result_json: value,
    generated_at: new Date().toISOString(),
  });
}

async function findCatalogReplacement(brand: string, discontinuedProduct: string) {
  const { data: brandRow } = await supabase
    .from("brand")
    .select("brand_id")
    .ilike("brand_name", brand)
    .maybeSingle();

  if (!brandRow) return null;

  const { data, error } = await supabase
    .from("product")
    .select(`
      product_name,
      product_variant (
        product_variant_size ( stock_quantity, reserved_quantity )
      )
    `)
    .eq("is_archived", false)
    .eq("brand_id", brandRow.brand_id)
    .neq("product_name", discontinuedProduct)
    .limit(20);

  if (error || !data) return null;

  const match = data.find((row: any) => {
    const variants = row.product_variant ?? [];
    return variants.some((v: any) =>
      (v.product_variant_size ?? []).some(
        (s: any) => (s.stock_quantity ?? 0) - (s.reserved_quantity ?? 0) > 0
      )
    );
  });

  if (!match) return null;

  return {
    recommendedReplacement: match.product_name,
    reasoning: `${match.product_name} is already in our own ${brand} catalog, currently active, and in stock.`,
    source: "catalog",
  };
}

async function findWebReplacement(
  discontinuedProduct: string,
  brand: string,
  availableBrands: string[],
  promptStyle: "customer_redirect" | "new_product_suggestion"
) {
  const domains = BRAND_DOMAINS[brand] ?? [];

  const prompt =
    promptStyle === "new_product_suggestion"
      ? `A sneaker retailer previously carried "${discontinuedProduct}" (brand: ${brand}), ` +
        `now discontinued/archived. The store's fixed brand list is: ` +
        `${JSON.stringify(availableBrands)}. Search the web for ${brand}'s current, ` +
        `actively-produced sneaker lineup and recommend ONE specific current model the ` +
        `store should CONSIDER ADDING to its inventory as a modern successor to ` +
        `"${discontinuedProduct}" — this is a business/buying decision, not a customer ` +
        `redirect. Justify briefly with current demand/popularity if known. ` +
        `Respond with ONLY a JSON object, no markdown, no code fences: ` +
        `{"recommendedReplacement": "exact product name", "reasoning": "one sentence why this is worth stocking"}`
      : `A sneaker retailer has discontinued "${discontinuedProduct}" (brand: ${brand}). ` +
        `Search the web for ${brand}'s current sneaker lineup and suggest the closest ` +
        `current-generation replacement sneaker from the SAME brand (${brand}) that is ` +
        `still in production today. The store only carries these brands: ${JSON.stringify(availableBrands)} — ` +
        `only suggest a product from brand "${brand}" specifically. ` +
        `Respond with ONLY a JSON object, no markdown, no code fences, no extra sentences ` +
        `before or after the JSON: ` +
        `{"recommendedReplacement": "exact product name", "reasoning": "one sentence why"}`;

  const tool: Record<string, unknown> = { type: "web_search" };
  if (domains.length > 0) {
    tool.filters = { allowed_domains: domains };
  }

  const res = await fetch(OPENAI_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      tools: [tool],
      input: prompt,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI API error ${res.status}: ${errText}`);
  }

  const data = await res.json();

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

  const jsonMatch = rawText.match(/\{[\s\S]*\}/);
  const cleaned = jsonMatch ? jsonMatch[0] : rawText.replace(/```json|```/g, "").trim();

  try {
    const parsed = JSON.parse(cleaned);
    return { ...parsed, source: "web_search" };
  } catch {
    console.error("JSON parse failed. Cleaned text was:", cleaned);
    return {
      recommendedReplacement: "Unable to determine",
      reasoning: "Could not parse a confident suggestion from the model's response.",
      source: "web_search",
    };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing authorization" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: { user } } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );

    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { data: profile } = await supabase
      .from("users")
      .select("role")
      .eq("id", user.id)
      .maybeSingle();

    if (profile?.role !== "Super Admin") {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden — Super Admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { discontinuedProduct, brand, availableBrands, mode, forceRefresh } = await req.json();

    if (!discontinuedProduct || typeof discontinuedProduct !== "string" ||
        !brand || typeof brand !== "string") {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid payload" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const resolvedMode: "customer_replacement" | "new_product_suggestion" =
      mode === "new_product_suggestion" ? "new_product_suggestion" : "customer_replacement";

    const cacheKey = `${resolvedMode}:${brand}:${discontinuedProduct}`;
    const wantsForceRefresh = forceRefresh === true;

    if (!wantsForceRefresh) {
      const cached = await getCached(cacheKey);
      if (cached) {
        return new Response(
          JSON.stringify({ success: true, data: { discontinuedProduct, brand, ...(cached as object) } }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    } else {
      // Forced refresh is allowed, but cooldown-gated — prevents
      // repeated clicking from triggering repeated paid calls, while
      // still letting an admin genuinely get a fresh take later.
      const lastGenerated = await getLastGeneratedAt(cacheKey);
      if (lastGenerated !== null && Date.now() - lastGenerated < FORCE_REFRESH_COOLDOWN_MS) {
        const waitSeconds = Math.ceil(
          (FORCE_REFRESH_COOLDOWN_MS - (Date.now() - lastGenerated)) / 1000
        );
        return new Response(
          JSON.stringify({
            success: false,
            error: `Please wait ${waitSeconds}s before requesting another refresh for this item.`,
          }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    let result;

    if (resolvedMode === "customer_replacement") {
      result = await findCatalogReplacement(brand, discontinuedProduct);
      if (!result) {
        result = await findWebReplacement(discontinuedProduct, brand, availableBrands, "customer_redirect");
      }
    } else {
      result = await findWebReplacement(discontinuedProduct, brand, availableBrands, "new_product_suggestion");
    }

    await setCached(cacheKey, result);

    return new Response(
      JSON.stringify({
        success: true,
        data: { discontinuedProduct, brand, ...result },
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