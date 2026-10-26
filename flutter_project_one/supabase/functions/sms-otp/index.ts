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

// Per phone number
const SEND_LIMIT = 3;
const SEND_WINDOW_MIN = 10;
const VERIFY_LIMIT = 5;
const VERIFY_WINDOW_MIN = 10;

// Per signed-in account, across ALL numbers. Without this, one account could
// text a code to many different people's phones (each costs an SMS).
const USER_SEND_LIMIT = 8;
const USER_SEND_WINDOW_MIN = 60;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// The 10 digits after +63 (for example 9171234567), or null if the value is
// not a Philippine mobile number. Accepts 09171234567, +639171234567,
// 639171234567 and 9171234567, ignoring spaces, dashes and brackets.
function nationalDigits(raw: unknown): string | null {
  if (typeof raw !== "string") return null;

  let digits = raw.replace(/\D/g, "");
  if (digits.length === 12 && digits.startsWith("63")) {
    digits = digits.slice(2);
  } else if (digits.length === 11 && digits.startsWith("0")) {
    digits = digits.slice(1);
  }

  return /^9\d{9}$/.test(digits) ? digits : null;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Must be a signed-in user.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: { user } } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (!user) {
      return json({ error: "Invalid session" }, 401);
    }

    const { action, phone_number, otp } = await req.json();

    // The number is cleaned up FIRST, so "09171234567" and "+639171234567"
    // count as the same number for the limits below. Before, each way of
    // writing the same number had its own separate allowance.
    const national = nationalDigits(phone_number);
    if (!national) {
      return json({ error: "A valid Philippine mobile number is required" }, 400);
    }
    const canonical = `63${national}`;

    // The format the SMS provider has been accepting for these codes (every
    // customer so far registered and verified with this form).
    const providerPhone = `0${national}`;

    let url = "";
    const body: Record<string, string> = {
      api_token: IPROG_API_TOKEN,
      phone_number: providerPhone,
    };

    if (action === "send") {
      const phoneWindowStart = new Date(Date.now() - SEND_WINDOW_MIN * 60 * 1000).toISOString();
      const { count } = await supabase
        .from("otp_attempts")
        .select("*", { count: "exact", head: true })
        .eq("phone_number", canonical)
        .eq("action", "send")
        .gte("created_at", phoneWindowStart);

      if ((count ?? 0) >= SEND_LIMIT) {
        return json({ error: "Too many OTP requests. Please wait a few minutes and try again." }, 429);
      }

      // Account-wide limit. If the user_id column does not exist yet this
      // check is skipped rather than blocking sign-ups.
      const userWindowStart = new Date(Date.now() - USER_SEND_WINDOW_MIN * 60 * 1000).toISOString();
      const { count: userCount, error: userCountError } = await supabase
        .from("otp_attempts")
        .select("*", { count: "exact", head: true })
        .eq("user_id", user.id)
        .eq("action", "send")
        .gte("created_at", userWindowStart);

      if (!userCountError && (userCount ?? 0) >= USER_SEND_LIMIT) {
        return json({ error: "Too many OTP requests. Please wait a while and try again." }, 429);
      }

      const { error: insertError } = await supabase
        .from("otp_attempts")
        .insert({ phone_number: canonical, action: "send", user_id: user.id });
      if (insertError) {
        // Older table without user_id: still record the attempt.
        await supabase.from("otp_attempts").insert({ phone_number: canonical, action: "send" });
      }

      url = `${BASE_URL}/send_otp`;
    } else if (action === "verify") {
      const code = String(otp ?? "").replace(/\s/g, "");
      if (!/^\d{4,10}$/.test(code)) {
        return json({ error: "A valid code is required" }, 400);
      }

      const windowStart = new Date(Date.now() - VERIFY_WINDOW_MIN * 60 * 1000).toISOString();
      const { count } = await supabase
        .from("otp_attempts")
        .select("*", { count: "exact", head: true })
        .eq("phone_number", canonical)
        .eq("action", "verify")
        .gte("created_at", windowStart);

      if ((count ?? 0) >= VERIFY_LIMIT) {
        return json({ error: "Too many attempts. Please request a new code." }, 429);
      }

      const { error: insertError } = await supabase
        .from("otp_attempts")
        .insert({ phone_number: canonical, action: "verify", user_id: user.id });
      if (insertError) {
        await supabase.from("otp_attempts").insert({ phone_number: canonical, action: "verify" });
      }

      url = `${BASE_URL}/verify_otp`;
      body.otp = code;
    } else {
      return json({ error: "Invalid action" }, 400);
    }

    const iprogResponse = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const data = await iprogResponse.json();

    // NEVER pass the provider's reply to the browser. For "send" it includes
    // the one-time code itself, which meant anyone could read the code from
    // the network response and "verify" a phone number that never received
    // a text message. Only the outcome goes back.
    return json({
      status: data?.status ?? "error",
      message: typeof data?.message === "string" ? data.message : undefined,
    });
  } catch (error) {
    console.error("sms-otp error:", error);
    return json({ error: "Could not process the request" }, 500);
  }
});