import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function decodeJwtPayload(token: string): Record<string, unknown> | null {
  try {
    const parts = token.split(".");
    if (parts.length !== 3) return null;
    const base64 = parts[1].replace(/-/g, "+").replace(/_/g, "/");
    const padded = base64.padEnd(base64.length + (4 - (base64.length % 4)) % 4, "=");
    return JSON.parse(atob(padded));
  } catch {
    return null;
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

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const { data: { user: callingUser } } = await adminClient.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (!callingUser) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { user_id, new_password } = await req.json();

    const { data: profile } = await adminClient
      .from("users")
      .select("role")
      .eq("id", callingUser.id)
      .maybeSingle();

    const isSelf = callingUser.id === user_id;
    const isSuperAdmin = profile?.role === "Super Admin";

    if (!isSelf && !isSuperAdmin) {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // AUDIT FIX: only require aal2 when a Super Admin is overriding
    // SOMEONE ELSE'S password — a genuine high-trust action. A person
    // resetting their OWN forgotten password must NOT be blocked by
    // this, since a real "I forgot my password" flow may not have a
    // session with completed MFA at all — that's the whole point of
    // password recovery.
    if (!isSelf) {
      const jwtPayload = decodeJwtPayload(authHeader.replace("Bearer ", ""));
      if (jwtPayload?.aal !== "aal2") {
        return new Response(
          JSON.stringify({ success: false, error: "This action requires completed two-factor authentication." }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    if (!user_id || !new_password) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing user_id or new_password" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    if (new_password.length < 8) {
      return new Response(
        JSON.stringify({ success: false, error: "Password must be at least 8 characters" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }
      
    const { error } = await adminClient.auth.admin.updateUserById(user_id, {
      password: new_password,
    });

    if (error) {
      console.error("updateUserById error:", error.message);
      return new Response(
        JSON.stringify({ success: false, error: error.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    console.log(`Password updated for user: ${user_id}`);

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("update-user-password error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});