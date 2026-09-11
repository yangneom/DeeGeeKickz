import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY")!;
const OPENAI_URL = "https://api.openai.com/v1/chat/completions";
const MODEL = "gpt-5.6-luna";

const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // once per day

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

// Turns the actual payload into a short hash so the cache key
// changes whenever the underlying sales/inventory data changes —
// previously the key was just "trend"/"trending"/"restock", so a
// stale prediction could be served for up to 24h even after real
// numbers changed.
async function hashPayload(payload: unknown): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(JSON.stringify(payload));
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")
    .slice(0, 16);
}

// ── Cache helper ─────────────────────────────────────────────
// Reads/writes ai_dashboard_cache. A cache miss (or stale/expired
// entry) falls through to computeFn(), then stores the fresh result.
// forceRefresh bypasses the read (used by a future manual "Refresh"
// button) but still writes the new result back into the cache.
async function getOrCompute(
  cacheKey: string,
  forceRefresh: boolean,
  computeFn: () => Promise<unknown>
) {
  if (!forceRefresh) {
    const cached = await getCached(cacheKey);
    if (cached) return cached;
  }

  const fresh = await computeFn();
  await setCached(cacheKey, fresh);
  return fresh;
}

// Used directly by handleRestock's per-item insight caching, and by
// getOrCompute above for the whole-feature caches (trend/trending).
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

async function setCached(cacheKey: string, value: unknown) {
  await supabase.from("ai_dashboard_cache").upsert({
    cache_key: cacheKey,
    result_json: value,
    generated_at: new Date().toISOString(),
  });
}

async function callOpenAI(systemPrompt: string, userPrompt: string) {
  const res = await fetch(OPENAI_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${OPENAI_API_KEY}`,
    },
        body: JSON.stringify({
      model: MODEL,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      // gpt-5.6-luna only supports the default temperature (1) —
      // confirmed via a real 400 error when 0.3 was sent. Newer
      // reasoning-oriented models often drop support for sampling
      // temperature entirely; omitting the field uses the default.
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`OpenAI API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error("OpenAI returned no content");
  return JSON.parse(content);
}

async function handleTrend(payload: { monthlySales: number[] }, forceRefresh: boolean) {
  // Fixed key, not hash-based — this is a directional trend forecast,
  // not an exact figure, so a few hours of slightly-stale data is an
  // acceptable tradeoff for guaranteeing at most one OpenAI call per
  // day regardless of how many orders come in during that day.
  return getOrCompute("trend", forceRefresh, () =>
    callOpenAI(
      `You are a retail sales forecaster for a sneaker store. Given a list of ` +
      `monthly revenue figures (in PHP), predict the next 3 months and give a ` +
      `one-sentence actionable insight. Respond ONLY with JSON: ` +
      `{"predictedSales": [number, number, number], "insight": "string"}`,
      `Monthly sales history (oldest to newest): ${JSON.stringify(payload.monthlySales)}`
    )
  );
}

async function handleTrending(
  payload: { salesData: { productName: string; salesCount: number; growthPercent: number }[] },
  forceRefresh: boolean
) {
  // Fixed key — same reasoning as "trend": strictly once per 24h,
  // even if sales data shifts during that window.
  return getOrCompute("trending", forceRefresh, async () => {
    const aiResult = await callOpenAI(
      `You are analyzing real sneaker sales data (numbers are already computed, ` +
      `do not change them). Select and rank EXACTLY the top 5 trending products ` +
      `(or fewer if fewer than 5 are given, ranked most to least significant). ` +
      `Respond ONLY with JSON: {"trending": [{"productName": "string", ` +
      `"salesCount": number, "growthPercent": number}]} using the exact ` +
      `numbers given, just reordered/selected by significance.`,
      `Sales data: ${JSON.stringify(payload.salesData)}`
    );

    return {
      trending: Array.isArray(aiResult.trending)
        ? aiResult.trending.slice(0, 5)
        : [],
    };
  });
}
async function handleRestock(
  payload: { inventoryData: { productName: string; currentStock: number; dailySalesRate: number }[] },
  forceRefresh: boolean
) {
    const { inventoryData } = payload;

    // AUDIT FIX: unlike Sales Trend/Trending Shoes, this feature is
    // an actionable alert, not just an insight — a 24h-stale cache
    // here means a real stockout (or a restock an admin already did)
    // could go unreflected for up to a day. So the actual "is this
    // low right now?" math ALWAYS runs fresh, every load, for free
    // (plain arithmetic, no API cost). Only the AI-written insight
    // SENTENCE for each flagged item gets cached — that's the only
    // part that actually costs money, and its exact wording doesn't
    // need to change just because a few minutes passed.
    const computed = inventoryData.map((item) => {
      const rate = item.dailySalesRate > 0 ? item.dailySalesRate : 0.1;
      const daysUntilStockout = Math.max(0, Math.round(item.currentStock / rate));
      const target = Math.ceil(rate * 30);
      const recommendedRestock = Math.max(0, target - item.currentStock);

      return {
        productName: item.productName,
        currentStock: item.currentStock,
        idealStock: target,
        daysUntilStockout,
        recommendedRestock,
      };
    });

    computed.sort((a, b) => a.daysUntilStockout - b.daysUntilStockout);

    if (computed.length === 0) {
      return { restockItems: [] };
    }

    // Cache key is keyed per-item (product name), NOT the whole
    // restock list — so the AI sentence for one item is reused across
    // loads even as OTHER items enter/leave the low-stock list.
    const itemsNeedingInsight: typeof computed = [];
    const cachedResults: Record<string, { insight: string }> = {};

    for (const item of computed) {
      const cacheKey = `restock_insight:${item.productName}`;
      const cached = forceRefresh ? null : await getCached(cacheKey);
      if (cached) {
        cachedResults[item.productName] = cached as { insight: string };
      } else {
        itemsNeedingInsight.push(item);
      }
    }

    if (itemsNeedingInsight.length > 0) {
      try {
        const aiResult = await callOpenAI(
          `You are a retail inventory assistant for a sneaker store. You will be ` +
          `given a list of products with precomputed stockout data (do not change ` +
          `any numbers). For each item, add a short one-sentence "insight" — a ` +
          `practical note about urgency or suggested action. Respond ONLY with JSON: ` +
          `{"restockItems": [{"productName": "string", "insight": "string"}]} — ` +
          `just the productName and insight for each, no other fields needed.`,
          `Restock data: ${JSON.stringify(itemsNeedingInsight)}`
        );

        for (const result of aiResult.restockItems ?? []) {
          cachedResults[result.productName] = { insight: result.insight };
          await setCached(`restock_insight:${result.productName}`, { insight: result.insight });
        }
      } catch (err) {
        console.error("OpenAI insight generation failed, falling back to no insight:", err);
      }
    }

    const restockItems = computed.map((item) => ({
      ...item,
      insight: cachedResults[item.productName]?.insight ?? '',
    }));

    return { restockItems };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Only a real, logged-in Super Admin may trigger this — otherwise
    // any authenticated account (even a Customer) could call this
    // endpoint directly and trigger real OpenAI spend, bypassing the
    // dashboard UI entirely.
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

       const { action, payload } = await req.json();

    if (!payload || typeof payload !== "object") {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid payload" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let result;

    // forceRefresh removed — no UI currently sends it; re-add with a
    // proper cooldown if a real "Refresh" button gets built later.
    if (action === "trend") {
      if (!Array.isArray(payload.monthlySales)) {
        return new Response(
          JSON.stringify({ success: false, error: "monthlySales must be an array" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      result = await handleTrend(payload, false);
    } else if (action === "trending") {
      if (!Array.isArray(payload.salesData)) {
        return new Response(
          JSON.stringify({ success: false, error: "salesData must be an array" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      result = await handleTrending(payload, false);
    } else if (action === "restock") {
      if (!Array.isArray(payload.inventoryData)) {
        return new Response(
          JSON.stringify({ success: false, error: "inventoryData must be an array" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
      result = await handleRestock(payload, false);
    } else {
      return new Response(
        JSON.stringify({ success: false, error: "Unknown action" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    return new Response(
      JSON.stringify({ success: true, data: result }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("ai-dashboard error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});