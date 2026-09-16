import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const IPROG_API_TOKEN = Deno.env.get("IPROG_API_TOKEN")!;
const BASE_URL = "https://sms.iprogtech.com/api/v1/otp";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const SEND_LIMIT = 3;
const SEND_WINDOW_MIN = 10;
const VERIFY_LIMIT = 5;
const VERIFY_WINDOW_MIN = 10;

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // AUDIT FIX: previously no auth check at all — anyone could
    // trigger real SMS sends (cost) or brute-force a 6-digit code
    // with zero rate limiting, for any phone number, with no login.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing authorization" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: { user } } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (!user) {
      return new Response(
        JSON.stringify({ error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { action, phone_number, otp } = await req.json();

    if (!phone_number) {
      return new Response(
        JSON.stringify({ error: "Missing phone_number" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    let url = "";
    const body: Record<string, string> = {
      api_token: IPROG_API_TOKEN,
      phone_number,
    };

    if (action === "send") {
      const windowStart = new Date(Date.now() - SEND_WINDOW_MIN * 60 * 1000).toISOString();
      const { count } = await supabase
        .from("otp_attempts")
        .select("*", { count: "exact", head: true })
        .eq("phone_number", phone_number)
        .eq("action", "send")
        .gte("created_at", windowStart);

      if ((count ?? 0) >= SEND_LIMIT) {
        return new Response(
          JSON.stringify({ error: "Too many OTP requests. Please wait a few minutes and try again." }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      await supabase.from("otp_attempts").insert({ phone_number, action: "send" });
      url = `${BASE_URL}/send_otp`;
    } else if (action === "verify") {
      const windowStart = new Date(Date.now() - VERIFY_WINDOW_MIN * 60 * 1000).toISOString();
      const { count } = await supabase
        .from("otp_attempts")
        .select("*", { count: "exact", head: true })
        .eq("phone_number", phone_number)
        .eq("action", "verify")
        .gte("created_at", windowStart);

      if ((count ?? 0) >= VERIFY_LIMIT) {
        return new Response(
          JSON.stringify({ error: "Too many attempts. Please request a new code." }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }

      await supabase.from("otp_attempts").insert({ phone_number, action: "verify" });
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