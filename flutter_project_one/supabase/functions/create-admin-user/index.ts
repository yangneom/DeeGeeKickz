import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// This must match exactly what you added to
// Supabase → Auth → URL Configuration → Redirect URLs
const INVITE_REDIRECT_URL =
  Deno.env.get("INVITE_REDIRECT_URL") ?? "http://localhost:5000/#/set-password";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { first_name, last_name, email, role } = await req.json();

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

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

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
      is_archived: false,
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