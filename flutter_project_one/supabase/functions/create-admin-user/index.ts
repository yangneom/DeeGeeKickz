import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { webUrl } from "../_shared/web_base.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// The Set Your Password page on the OFFICIAL site: https://deegeekickz.com/set-password
//
// The address is built by _shared/web_base.ts, which accepts ONLY the official domain
// (or local development) and ignores anything else, for example an old Firebase address
// still left in a server secret. Supabase must also allow it: Authentication -> URL
// Configuration (Site URL = https://deegeekickz.com).
//
// The app serves real paths now, so the page is /set-password (not the old "#/" hash route).
const INVITE_REDIRECT_URL = webUrl(
  Deno.env.get("INVITE_REDIRECT_URL") ?? Deno.env.get("WEB_BASE_URL"),
  "/set-password",
);

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

    const { data: callerProfile } = await adminClient
      .from("users")
      .select("role")
      .eq("id", callingUser.id)
      .maybeSingle();

    if (!callerProfile || callerProfile.role !== "Super Admin") {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden — Super Admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // AUDIT FIX: the Flutter MFA challenge screen only decided which
    // screen to show — it never actually gated anything server-side.
    // A valid aal1 (password-only) token could call this endpoint
    // directly, bypassing MFA entirely. This checks the real
    // assurance level embedded in the token itself.
    const jwtPayload = decodeJwtPayload(authHeader.replace("Bearer ", ""));
    if (jwtPayload?.aal !== "aal2") {
      return new Response(
        JSON.stringify({ success: false, error: "This action requires completed two-factor authentication." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { first_name, last_name, email, role } = await req.json();

    // Lock down exactly which roles can be created here — no arbitrary
    // string is accepted, closing the self-escalation path entirely.
    const allowedRoles = ["Admin", "Cashier", "Super Admin"];
    if (!allowedRoles.includes(role)) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid role" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // ── Validate input ──────────────────────────
    if (!first_name || !last_name || !email || !role) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing required fields" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    console.log(`Creating admin user: ${email} | role: ${role}`);
    console.log(`Redirect URL: ${INVITE_REDIRECT_URL}`);

    // ── Send invite email ───────────────────────
    // This creates the auth.users row AND sends
    // the invite email in one call.
    const { data, error: inviteError } =
      await adminClient.auth.admin.inviteUserByEmail(email, {
        data: {
          first_name,
          last_name,
          role,
        },
        redirectTo: INVITE_REDIRECT_URL,
      });

    if (inviteError) {
      console.error("inviteUserByEmail error:", inviteError.message);
      return new Response(
        JSON.stringify({ success: false, error: inviteError.message }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    const user = data.user;
    console.log(`Auth user created: ${user!.id}`);

    // ── Insert public.users profile row ─────────
    // password_set: false  →  triggers SetPasswordScreen
    // when the staff member first signs in
    const { error: insertError } = await adminClient.from("users").upsert({
      id:          user!.id,
      first_name,
      last_name,
      email,
      role,
      password_set: false,   // ← key flag for the invite flow
    });

    if (insertError) {
      console.error("profile insert error:", insertError.message);
      return new Response(
        JSON.stringify({ success: false, error: insertError.message }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        },
      );
    }

    console.log(`Profile row created for: ${email}`);

    return new Response(
      JSON.stringify({ success: true, user_id: user!.id }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("create-admin-user unexpected error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});