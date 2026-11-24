// Web Push (RFC 8030) με κρυπτογράφηση aes128gcm (RFC 8291 / RFC 8188) και VAPID (RFC 8292),
// μόνο με WebCrypto — χωρίς εξωτερικές βιβλιοθήκες. Δουλεύει σε Deno (Edge Functions) και σε Node 20+.

const enc = new TextEncoder();

export function b64uToBytes(s: string): Uint8Array {
  const b = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  const bin = atob(b);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
export function bytesToB64u(u: Uint8Array): string {
  let s = "";
  for (let i = 0; i < u.length; i++) s += String.fromCharCode(u[i]);
  return btoa(s).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function concat(...parts: Uint8Array[]): Uint8Array {
  const n = parts.reduce((a, p) => a + p.length, 0);
  const out = new Uint8Array(n);
  let o = 0;
  for (const p of parts) { out.set(p, o); o += p.length; }
  return out;
}

async function hkdf(salt: Uint8Array, ikm: Uint8Array, info: Uint8Array, len: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "HKDF", hash: "SHA-256", salt, info }, key, len * 8);
  return new Uint8Array(bits);
}

// Ιδιωτικό κλειδί P-256 από raw d (32 bytes) + δημόσιο (65 bytes, uncompressed)
async function importPrivate(dB64u: string, pubRaw: Uint8Array, usage: "sign" | "derive"): Promise<CryptoKey> {
  const jwk = { kty: "EC", crv: "P-256", d: dB64u, x: bytesToB64u(pubRaw.slice(1, 33)), y: bytesToB64u(pubRaw.slice(33, 65)), ext: true };
  return usage === "sign"
    ? crypto.subtle.importKey("jwk", jwk, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"])
    : crypto.subtle.importKey("jwk", jwk, { name: "ECDH", namedCurve: "P-256" }, false, ["deriveBits"]);
}

export type Subscription = { endpoint: string; p256dh: string; auth: string };

// Κρυπτογράφηση payload για μία συνδρομή. Τα salt / asPriv είναι προαιρετικά (μόνο για τον έλεγχο με το RFC 8291).
export async function encryptPayload(
  sub: Subscription, payload: Uint8Array,
  fixed?: { salt: Uint8Array; asPrivD: string; asPub: Uint8Array },
): Promise<Uint8Array> {
  const uaPub = b64uToBytes(sub.p256dh);
  const authSecret = b64uToBytes(sub.auth);
  let asPub: Uint8Array, asPrivKey: CryptoKey;
  if (fixed) {
    asPub = fixed.asPub;
    asPrivKey = await importPrivate(fixed.asPrivD, asPub, "derive");
  } else {
    const kp = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]) as CryptoKeyPair;
    asPub = new Uint8Array(await crypto.subtle.exportKey("raw", kp.publicKey));
    asPrivKey = kp.privateKey;
  }
  const uaKey = await crypto.subtle.importKey("raw", uaPub, { name: "ECDH", namedCurve: "P-256" }, false, []);
  const ecdh = new Uint8Array(await crypto.subtle.deriveBits({ name: "ECDH", public: uaKey }, asPrivKey, 256));
  const keyInfo = concat(enc.encode("WebPush: info\0"), uaPub, asPub);
  const ikm = await hkdf(authSecret, ecdh, keyInfo, 32);
  const salt = fixed ? fixed.salt : crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, enc.encode("Content-Encoding: aes128gcm\0"), 16);
  const nonce = await hkdf(salt, ikm, enc.encode("Content-Encoding: nonce\0"), 12);
  const aes = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  const plain = concat(payload, new Uint8Array([2]));        // 0x02 = τελευταίο record, χωρίς padding
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: "AES-GCM", iv: nonce }, aes, plain));
  const rs = new Uint8Array([0, 0, 16, 0]);                  // record size 4096
  return concat(salt, rs, new Uint8Array([asPub.length]), asPub, ct);
}

// VAPID JWT (ES256) για το origin του endpoint
export async function vapidHeader(endpoint: string, vapidPub: string, vapidPrivD: string, subject: string): Promise<string> {
  const aud = new URL(endpoint).origin;
  const header = bytesToB64u(enc.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const claims = bytesToB64u(enc.encode(JSON.stringify({ aud, exp: Math.floor(Date.now() / 1000) + 12 * 3600, sub: subject })));
  const unsigned = `${header}.${claims}`;
  const key = await importPrivate(vapidPrivD, b64uToBytes(vapidPub), "sign");
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, enc.encode(unsigned)));
  return `vapid t=${unsigned}.${bytesToB64u(sig)}, k=${vapidPub}`;
}

// Αποστολή. Επιστρέφει το HTTP status (201 = εντάξει, 404/410 = η συνδρομή δεν ισχύει πια)
export async function sendPush(
  sub: Subscription, data: unknown,
  vapid: { publicKey: string; privateKey: string; subject: string },
  opts: { ttl?: number; urgency?: string; topic?: string } = {},
): Promise<number> {
  const body = await encryptPayload(sub, enc.encode(JSON.stringify(data)));
  const headers: Record<string, string> = {
    "Content-Encoding": "aes128gcm",
    "Content-Type": "application/octet-stream",
    "TTL": String(opts.ttl ?? 120),
    "Urgency": opts.urgency ?? "high",
    "Authorization": await vapidHeader(sub.endpoint, vapid.publicKey, vapid.privateKey, vapid.subject),
  };
  if (opts.topic) headers["Topic"] = opts.topic;
  const r = await fetch(sub.endpoint, { method: "POST", headers, body });
  try { await r.arrayBuffer(); } catch { /* */ }
  return r.status;
}
