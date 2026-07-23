// ================================================
// SHARED LALAMOVE HELPERS
// Used by: get-delivery-quote, create-delivery-order
//
// Signature spec (per Lalamove v3 docs):
//   SIGNATURE = HmacSHA256Hex(
//     `${timestamp}\r\n${method}\r\n${path}\r\n\r\n${body}`,
//     API_SECRET
//   )
//   Authorization: hmac {API_KEY}:{timestamp}:{SIGNATURE}
// ================================================

const LALAMOVE_BASE_URL =
  Deno.env.get("LALAMOVE_ENV") === "production"
    ? "https://rest.lalamove.com"
    : "https://rest.sandbox.lalamove.com";

const API_KEY = Deno.env.get("LALAMOVE_API_KEY")!;
const API_SECRET = Deno.env.get("LALAMOVE_API_SECRET")!;
const MARKET = Deno.env.get("LALAMOVE_MARKET") ?? "PH";

async function hmacSha256Hex(message: string, secret: string): Promise<string> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(message),
  );
  return Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Calls a Lalamove v3 endpoint with a correctly signed request.
 * `path` must start with "/v3/..." — it's used both in the URL and
 * in the signature base string, so it has to match exactly.
 */
export async function callLalamove({
  method,
  path,
  body,
}: {
  method: "GET" | "POST" | "PATCH";
  path: string;
  body?: Record<string, unknown>;
}): Promise<{ ok: boolean; status: number; json: any }> {
  const timestamp = Date.now().toString();
  const bodyString = body ? JSON.stringify(body) : "";

  const rawSignature = `${timestamp}\r\n${method}\r\n${path}\r\n\r\n${bodyString}`;
  const signature = await hmacSha256Hex(rawSignature, API_SECRET);

  const requestId = crypto.randomUUID();

  const response = await fetch(`${LALAMOVE_BASE_URL}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      "Authorization": `hmac ${API_KEY}:${timestamp}:${signature}`,
      "Market": MARKET,
      "Request-ID": requestId,
    },
    body: bodyString || undefined,
  });

  const json = await response.json().catch(() => ({}));
  return { ok: response.ok, status: response.status, json };
}

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};