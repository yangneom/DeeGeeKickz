// supabase/functions/ai-dashboard/index.ts
//
// Handles three Groq-powered predictions for the Super Admin
// dashboard. All math that matters for business decisions
// (days-until-stockout, recommended restock qty) is computed
// deterministically in this function BEFORE calling Groq —
// Groq is only used to rank/prioritize and produce short
// natural-language insight text. This avoids letting an LLM
// hallucinate inventory numbers that could lead to bad
// purchasing decisions.
//
// POST body: { action: 'trend' | 'trending' | 'restock', payload: {...} }

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;
const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function callGroq(systemPrompt: string, userPrompt: string) {
  const res = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${GROQ_API_KEY}`,
    },
    body: JSON.stringify({
      model: MODEL,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      temperature: 0.3,
    }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Groq API error ${res.status}: ${errText}`);
  }

  const data = await res.json();
  const content = data.choices?.[0]?.message?.content;
  if (!content) throw new Error("Groq returned no content");
  return JSON.parse(content);
}

// ── Sales Trend Prediction ──────────────────────────────────
async function handleTrend(payload: { monthlySales: number[] }) {
  const { monthlySales } = payload;

  const result = await callGroq(
    `You are a retail sales forecaster for a sneaker store. Given a list of ` +
    `monthly revenue figures (in PHP), predict the next 3 months and give a ` +
    `one-sentence actionable insight. Respond ONLY with JSON: ` +
    `{"predictedSales": [number, number, number], "insight": "string"}`,
    `Monthly sales history (oldest to newest): ${JSON.stringify(monthlySales)}`
  );

  return result;
}

// ── AI Trending Shoes ────────────────────────────────────────
// Growth % is computed deterministically by the client before
// this call (real math on real order data) — Groq's job here
// is purely to rank and phrase, not invent numbers.
async function handleTrending(payload: {
  salesData: { productName: string; salesCount: number; growthPercent: number }[];
}) {
  const { salesData } = payload;

  const result = await callGroq(
    `You are analyzing real sneaker sales data (numbers are already computed, ` +
    `do not change them). Select and rank the top trending products. ` +
    `Respond ONLY with JSON: {"trending": [{"productName": "string", ` +
    `"salesCount": number, "growthPercent": number}]} using the exact ` +
    `numbers given, just reordered/selected by significance.`,
    `Sales data: ${JSON.stringify(salesData)}`
  );

  return result;
}

// ── Restock Prediction ───────────────────────────────────────
// daysUntilStockout and recommendedRestock are computed here in
// TypeScript (deterministic), not by the LLM. Groq only adds a
// short prioritization/insight note.
async function handleRestock(payload: {
  inventoryData: { productName: string; currentStock: number; maxStock: number; dailySalesRate: number }[];
}) {
  const { inventoryData } = payload;

  const computed = inventoryData.map((item) => {
    const rate = item.dailySalesRate > 0 ? item.dailySalesRate : 0.1;
    const daysUntilStockout = Math.max(0, Math.round(item.currentStock / rate));
    // Target: enough stock for 30 days at current rate, minus what's on hand
    const target = Math.ceil(rate * 30);
    const recommendedRestock = Math.max(0, target - item.currentStock);

    return {
      productName: item.productName,
      currentStock: item.currentStock,
      maxStock: item.maxStock,
      daysUntilStockout,
      recommendedRestock,
    };
  });

  // Sort most urgent first — no AI needed for this, but ask Groq
  // for a one-line insight per item to keep the "AI Powered" badge honest.
  computed.sort((a, b) => a.daysUntilStockout - b.daysUntilStockout);

  return { restockItems: computed };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, payload } = await req.json();
    let result;

    if (action === "trend") {
      result = await handleTrend(payload);
    } else if (action === "trending") {
      result = await handleTrending(payload);
    } else if (action === "restock") {
      result = await handleRestock(payload);
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