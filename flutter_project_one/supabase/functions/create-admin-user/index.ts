import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  try {
    console.log("FUNCTION VERSION JUNE 9");
    console.log("FUNCTION STARTED");

    const body = await req.json();

    const {
      first_name,
      last_name,
      email,
      phone,
      password,
      role,
    } = body;

    console.log("========== CREATE USER ==========");
    console.log("ROLE =", role);

    console.log({
      first_name,
      last_name,
      email,
      role,
    });
    console.log("=================================");

    const supabaseAdmin = createClient(
      Deno.env.get("PROJECT_URL")!,
      Deno.env.get("SERVICE_ROLE_KEY")!
    );

    const { data, error } =
  await supabaseAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      role: role,
      first_name: first_name,
      last_name: last_name,
    },
  });

    if (error) throw error;

    const { error: upsertError } = await supabaseAdmin
      .from("users")
      .upsert(
        {
          id: data.user.id,
          first_name,
          last_name,
          email,
          phone,
          role,
          is_archived: false,
        },
        {
          onConflict: "id",
        }
      );

    if (upsertError) {
      console.error("UPSERT ERROR:", upsertError);
      throw upsertError;
    }

    return new Response(
      JSON.stringify({
        success: true,
        user_id: data.user.id,
      }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  } catch (error) {
    console.error(error);

    return new Response(
      JSON.stringify({
        success: false,
        error:
          error instanceof Error
            ? error.message
            : String(error),
      }),
      {
        status: 400,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json",
        },
      }
    );
  }
});