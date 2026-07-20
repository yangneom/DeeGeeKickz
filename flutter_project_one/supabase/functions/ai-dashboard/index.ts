// supabase/functions/ai-dashboard/index.ts
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
// "target" = ideal stock level for 30 days of runway at current
// sales pace. This replaces the old fake maxStock:100 placeholder —
// the progress bar now compares real stock against a real,
// sales-driven target instead of a made-up ceiling.
async function handleRestock(payload: {
  inventoryData: { productName: string; currentStock: number; dailySalesRate: number }[];
}) {
  const { inventoryData } = payload;

  const computed = inventoryData.map((item) => {
    const rate = item.dailySalesRate > 0 ? item.dailySalesRate : 0.1;
    const daysUntilStockout = Math.max(0, Math.round(item.currentStock / rate));
    const target = Math.ceil(rate * 30); // ideal 30-day stock level
    const recommendedRestock = Math.max(0, target - item.currentStock);

    return {
      productName: item.productName,
      currentStock: item.currentStock,
      idealStock: target,          // ← new: real number, replaces fake maxStock
      daysUntilStockout,
      recommendedRestock,
    };
  });

  computed.sort((a, b) => a.daysUntilStockout - b.daysUntilStockout);

  if (computed.length === 0) {
    return { restockItems: [] };
  }

  try {
    const withInsights = await callGroq(
      `You are a retail inventory assistant for a sneaker store. You will be ` +
      `given a list of products with precomputed stockout data (do not change ` +
      `any numbers). For each item, add a short one-sentence "insight" — a ` +
      `practical note about urgency or suggested action. Respond ONLY with JSON: ` +
      `{"restockItems": [{"productName": "string", "currentStock": number, ` +
      `"idealStock": number, "daysUntilStockout": number, "recommendedRestock": number, ` +
      `"insight": "string"}]} preserving every item and every number exactly as given.`,
      `Restock data: ${JSON.stringify(computed)}`
    );
    return withInsights;
  } catch (err) {
    console.error("Groq insight generation failed, falling back to raw data:", err);
    return { restockItems: computed };
  }
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