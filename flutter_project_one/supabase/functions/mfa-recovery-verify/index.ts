import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const MAX_ATTEMPTS = 5;
const WINDOW_MIN = 15;

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

    const { data: { user } } = await adminClient.auth.getUser(
      authHeader.replace("Bearer ", "")
    );
    if (!user) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid session" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    const { code } = await req.json();
    console.log(`RECOVERY_DEBUG: received code length=${code?.length}, value=[${code}]`);
    if (!code) {      return new Response(
        JSON.stringify({ success: false, error: "Missing code" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Counts EVERY attempt toward the limit, not just failures —
    // the safer default, since it can't be probed indefinitely.
    const windowStart = new Date(Date.now() - WINDOW_MIN * 60 * 1000).toISOString();
    const { count } = await adminClient
      .from("mfa_recovery_attempts")
      .select("*", { count: "exact", head: true })
      .eq("user_id", user.id)
      .gte("created_at", windowStart);

    if ((count ?? 0) >= MAX_ATTEMPTS) {
      return new Response(
        JSON.stringify({ success: false, error: "Too many attempts. Please try again later." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    await adminClient.from("mfa_recovery_attempts").insert({ user_id: user.id });

    const { data: isValid, error: rpcError } = await adminClient.rpc(
      "verify_mfa_recovery_code",
      { p_user_id: user.id, p_code: code },
    );

    if (rpcError || !isValid) {
      return new Response(
        JSON.stringify({ success: false, error: "Invalid or already-used recovery code." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } },
      );
    }

    // Valid code — remove the old factor(s) so re-enrollment can
    // start clean. This does NOT touch session AAL in any way — the
    // account remains aal1 until a real mfa.verify() succeeds on a
    // brand-new factor, per the design we agreed on.
    const { data: factorsData } = await adminClient.auth.admin.mfa.listFactors({
      userId: user.id,
    });

    for (const factor of factorsData?.factors ?? []) {
      await adminClient.auth.admin.mfa.deleteFactor({ id: factor.id, userId: user.id });
    }

    // SECURITY FIX: deleting the factor alone doesn't invalidate an
    // already-issued aal2 token — that claim lives in the JWT itself
    // and survives until the token naturally expires/refreshes. A
    // stale, still-valid aal2 token from BEFORE this reset could
    // otherwise keep working on every aal2-gated action. Force a
    // global sign-out so any such token stops working immediately.
    await adminClient.auth.admin.signOut(user.id, "global");

    return new Response(      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err) {
    console.error("mfa-recovery-verify error:", err);
    return new Response(
      JSON.stringify({ success: false, error: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }
});