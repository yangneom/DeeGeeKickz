import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
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

    // Only Super Admin can reset someone ELSE'S 2FA — a deliberately
    // high-trust action requiring a second person's judgment, not
    // something any staff member can trigger on their own.
    const { data: callerProfile } = await adminClient
      .from("users")
      .select("role")
      .eq("id", callingUser.id)
      .maybeSingle();

        if (!callerProfile || callerProfile.role !== "Super Admin") {
      return new Response(
        JSON.stringify({ success: false, error: "Forbidden, Super Admin only" }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // AUDIT FIX: resetting someone's MFA is exactly the kind of
    // high-trust action that must itself require the CALLER's own
    // session to have completed MFA — an aal1 (password-only)
    // Super Admin session shouldn't be able to strip another
    // account's protection.
    const jwtPayload = decodeJwtPayload(authHeader.replace("Bearer ", ""));
    if (jwtPayload?.aal !== "aal2") {
      return new Response(
        JSON.stringify({ success: false, error: "This action requires completed two-factor authentication." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { target_user_id } = await req.json();
    if (!target_user_id) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing target_user_id" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Delete EVERY factor for the target user, not just one — in
    // case multiple exist from earlier enrollment attempts, which is
    // exactly the scenario we were chasing a few messages ago.
    const { data: factorsData, error: listError } =
      await adminClient.auth.admin.mfa.listFactors({ userId: target_user_id });

    if (listError) {
      return new Response(
        JSON.stringify({ success: false, error: listError.message }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

        for (const factor of factorsData?.factors ?? []) {
      await adminClient.auth.admin.mfa.deleteFactor({
        id: factor.id,
        userId: target_user_id,
      });
    }

    // SECURITY FIX: deleting the factor alone doesn't invalidate an
    // already-issued aal2 token — that claim lives in the JWT itself
    // and survives until the token naturally expires. A stale,
    // still-valid aal2 token from BEFORE this reset (e.g. from
    // earlier testing) could otherwise keep bypassing every
    // aal2-gated check, exactly as just observed with the Admin
    // account landing straight on the dashboard after a refresh.
    // admin.signOut() takes the user's own ACCESS TOKEN, not a user id, so the id made
    // the old call fail silently. Supabase Auth has no admin route to end another
    // user's sessions, so this uses a database function that only the service role
    // may run (see revoke_user_sessions.sql).
    const { error: revokeError } = await adminClient.rpc("revoke_user_sessions", {
      p_user_id: target_user_id,
    });
    if (revokeError) {
      // The factors are already removed; do not undo that. Log the reason, no secrets.
      console.error("reset-mfa: could not end the target's sessions:", revokeError.message);
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("reset-mfa error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});