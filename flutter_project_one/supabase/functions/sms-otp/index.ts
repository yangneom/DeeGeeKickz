import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const IPROG_API_TOKEN = Deno.env.get("IPROG_API_TOKEN")!;
const BASE_URL = "https://sms.iprogtech.com/api/v1/otp";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, phone_number, otp } = await req.json();

    let url = "";
    const body: Record<string, string> = {
      api_token: IPROG_API_TOKEN,
      phone_number,
    };

    if (action === "send") {
      url = `${BASE_URL}/send_otp`;
    } else if (action === "verify") {
      url = `${BASE_URL}/verify_otp`;
      body.otp = otp;
    } else {
      return new Response(JSON.stringify({ error: "Invalid action" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const iprogResponse = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const data = await iprogResponse.json();

    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});