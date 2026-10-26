import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const IPROG_API_TOKEN = Deno.env.get("IPROG_API_TOKEN")!;
const SMS_URL = "https://sms.iprogtech.com/api/v1/sms_messages";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Staff may text any customer (for example "your order was rejected").
const STAFF_ROLES = ["Admin", "Super Admin", "Cashier"];

// Two SMS segments. Keeps a single request from sending a huge message.
const MAX_MESSAGE_LENGTH = 320;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Philippine mobile number in the form the SMS provider expects:
// 639XXXXXXXXX (country code, no "+", no leading "0").
// Accepts 09XXXXXXXXX, +639XXXXXXXXX, 639XXXXXXXXX and 9XXXXXXXXX,
// ignoring spaces, dashes and brackets. Anything else returns null.
function normalizePhone(raw: unknown): string | null {
  if (typeof raw !== "string") return null;

  let digits = raw.replace(/[^\d+]/g, "");
  if (digits.startsWith("+")) digits = digits.slice(1);

  if (digits.startsWith("0")) {
    digits = "63" + digits.slice(1);
  } else if (digits.length === 10 && digits.startsWith("9")) {
    digits = "63" + digits;
  }

  return /^639\d{9}$/.test(digits) ? digits : null;
}

// The last 10 digits, so 09171234567 and +639171234567 compare as equal.
function lastTen(value: string): string {
  return value.replace(/\D/g, "").slice(-10);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // BEFORE: no sign-in check at all. The public "anon" key that is built
    // into the website was enough to call this function, so anyone could send
    // any text message to any phone number at the shop's expense.
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "Missing authorization" }, 401);
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    // The anon key is not a signed-in user, so this rejects it.
    const { data: { user } } = await supabase.auth.getUser(
      authHeader.replace("Bearer ", ""),
    );
    if (!user) {
      return json({ error: "Invalid session" }, 401);
    }

    const { phone_number, message } = await req.json();

    const phone = normalizePhone(phone_number);
    if (!phone) {
      return json({ error: "A valid Philippine mobile number is required" }, 400);
    }

    const text = typeof message === "string" ? message.trim() : "";
    if (!text || text.length > MAX_MESSAGE_LENGTH) {
      return json({ error: `message is required (max ${MAX_MESSAGE_LENGTH} characters)` }, 400);
    }

    // Staff can text any customer. Anyone else can only text the number on
    // their own account.
    const { data: profile } = await supabase
      .from("users")
      .select("role, phone")
      .eq("id", user.id)
      .maybeSingle();

    const isStaff = STAFF_ROLES.includes(profile?.role ?? "");
    if (!isStaff) {
      const own = lastTen(profile?.phone ?? "");
      if (own.length !== 10 || own !== lastTen(phone)) {
        return json({ error: "Not authorized to send to this number" }, 403);
      }
    }

    const body = {
      api_token: IPROG_API_TOKEN,
      phone_number: phone,
      message: text,
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

    return json(data, iprogResponse.ok ? 200 : 502);
  } catch (error) {
    console.error("send-order-sms error:", error);
    return json({ error: "Could not send the message" }, 500);
  }
});