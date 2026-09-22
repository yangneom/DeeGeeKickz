// supabase/functions/disable-account/index.ts
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

        const { data: profile } = await adminClient
      .from("users")
      .select("role, first_name, last_name")
      .eq("id", callingUser.id)
      .maybeSingle();

    const allowedRoles = ["Admin", "Super Admin"];
    if (!profile || !allowedRoles.includes(profile.role)) {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // AUDIT FIX: disabling an account is a high-trust action, same
    // tier as creating a staff account — requires the CALLER's
    // session to have actually completed MFA, not just password auth.
    const jwtPayload = decodeJwtPayload(authHeader.replace("Bearer ", ""));
    if (jwtPayload?.aal !== "aal2") {
      return new Response(
        JSON.stringify({ success: false, error: "This action requires completed two-factor authentication." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { user_id, reason } = await req.json();

    if (!user_id) {
      return new Response(
        JSON.stringify({ success: false, error: "user_id is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 1. Flip the disabled flag (same as before)
    const { error: updateError } = await adminClient
      .from("users")
      .update({
        is_disabled: true,
        disabled_reason: reason ?? null,
        disabled_at: new Date().toISOString(),
      })
      .eq("id", user_id);

    if (updateError) {
      return new Response(
        JSON.stringify({ success: false, error: updateError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // 2. Force-kill their session — this is the new part.
    // 'global' scope revokes every device they're logged in on,
    // not just one. Their app will error out on their very next
    // request and get bounced to login.
    const { error: signOutError } = await adminClient.auth.admin.signOut(
      user_id,
      "global",
    );

    if (signOutError) {
      // Don't fail the whole request over this — the disable itself
      // already succeeded, and RLS (Part 2) is the backup net anyway.
      console.error("signOut error (non-fatal):", signOutError.message);
    }

    // Records WHO disabled this account, reusing the existing
    // activity_log table rather than adding a new disabled_by
    // column — "disabled by" is answerable by querying this log,
    // the same way every other admin action already is.
    const adminName = `${profile?.first_name ?? ""} ${profile?.last_name ?? ""}`.trim() || "Unknown";
    await adminClient.from("activity_log").insert({
      admin_id: callingUser.id,
      admin_name: adminName,
      role: profile?.role ?? "Unknown",
      action: `Disabled account (${reason ?? "no reason given"})`,
      affected_module: "Customer Management",
      target_id: user_id,
      metadata: { reason: reason ?? null },
    });

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});