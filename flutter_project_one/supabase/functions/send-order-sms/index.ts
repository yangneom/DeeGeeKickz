import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const IPROG_API_TOKEN = Deno.env.get("IPROG_API_TOKEN")!;
const SMS_URL = "https://sms.iprogtech.com/api/v1/sms_messages";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { phone_number, message } = await req.json();

    if (!phone_number || !message) {
      return new Response(JSON.stringify({ error: "phone_number and message are required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const body = {
      api_token: IPROG_API_TOKEN,
      phone_number,
      message,
    };

    // Send as BOTH query params and JSON body — covers whichever
    // format this endpoint actually reads, since it's undocumented
    // whether sms_messages parses the same way as otp/send_otp does.
    const params = new URLSearchParams(body);
    const urlWithParams = `${SMS_URL}?${params.toString()}`;

    const iprogResponse = await fetch(urlWithParams, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const data = await iprogResponse.json();

    console.log("iProg sms_messages response:", JSON.stringify(data));

    return new Response(JSON.stringify(data), {
      status: iprogResponse.ok ? 200 : 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});