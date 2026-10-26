// supabase/functions/_shared/web_base.ts
//
// THE ONE PLACE that says what the official web address is.
//
// Every Edge Function that sends a person back to the website (the staff invitation
// link, the GCash / online-payment return, the card 3-D Secure return) builds that
// address from here, so the official domain is written down once and cannot drift.
//
// WHAT IT ALLOWS
//   - the official address:  https://deegeekickz.com   (and nothing else in production)
//   - local development:     http://localhost:<port> or http://127.0.0.1:<port>
//     (so testing on your own machine still works)
//
// WHAT IT DOES WITH ANYTHING ELSE
//   An old Firebase address, a previous domain, a typo, the "www" address, "http" for the
//   official domain, a lookalike (deegeekickz.com.something-else.example) or an address
//   that cannot be read at all is IGNORED and the official address is used instead. A
//   warning naming only the HOST (never a path, query or token) is written to the logs.
//
// It only reads text that YOU put in a server secret. It never reads an address from
// a request, so a customer or staff member cannot choose where they are sent.

export const CANONICAL_WEB_BASE = "https://deegeekickz.com";

/** The origin (scheme + host + port, no path) people are sent back to. */
export function officialWebBase(raw: string | null | undefined): string {
  const text = (raw ?? "").trim();
  if (text === "") return CANONICAL_WEB_BASE;

  try {
    const u = new URL(text);
    const isOfficial = u.origin === CANONICAL_WEB_BASE;
    const isLocalDev =
      u.protocol === "http:" &&
      (u.hostname === "localhost" || u.hostname === "127.0.0.1");
    if (isOfficial || isLocalDev) return u.origin;
    console.warn(`Ignoring a web address that is not the official domain (host: ${u.host}).`);
  } catch (_) {
    console.warn("Ignoring a web address that could not be read.");
  }
  return CANONICAL_WEB_BASE;
}

/** A full address on the official site, for example webUrl(raw, "/set-password"). */
export function webUrl(raw: string | null | undefined, path: string): string {
  const clean = path.startsWith("/") ? path : `/${path}`;
  return `${officialWebBase(raw)}${clean}`;
}