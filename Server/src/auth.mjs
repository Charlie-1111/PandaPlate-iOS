import {
  createHmac,
  createPublicKey,
  timingSafeEqual,
  verify as verifySignature,
} from "node:crypto";

const IDENTITY_PROVIDERS = {
  apple: {
    issuer: "https://appleid.apple.com",
    jwksURL: "https://appleid.apple.com/auth/keys",
    algorithm: "ES256",
  },
  google: {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    jwksURL: "https://www.googleapis.com/oauth2/v3/certs",
    algorithm: "RS256",
  },
};
const SESSION_ISSUER = "pandaplate-proxy";
const SESSION_AUDIENCE = "pandaplate-ios";
const SESSION_TTL_SECONDS = 7 * 24 * 60 * 60;
const MAX_JWKS_BYTES = 64 * 1024;
const jwksCache = new Map();

function decodeSegment(value) {
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]+$/.test(value)) throw new Error("invalid_token");
  return Buffer.from(value, "base64url");
}

function parseJWT(token) {
  if (typeof token !== "string" || token.length > 12_000) throw new Error("invalid_token");
  const parts = token.split(".");
  if (parts.length !== 3 || parts.some((part) => !part)) throw new Error("invalid_token");
  let header;
  let payload;
  try {
    header = JSON.parse(decodeSegment(parts[0]).toString("utf8"));
    payload = JSON.parse(decodeSegment(parts[1]).toString("utf8"));
  } catch {
    throw new Error("invalid_token");
  }
  return { header, payload, signingInput: `${parts[0]}.${parts[1]}`, signature: decodeSegment(parts[2]) };
}

async function loadJWKS(provider, fetchImpl, nowMilliseconds) {
  const config = IDENTITY_PROVIDERS[provider];
  if (!config) throw new Error("unsupported_identity_provider");
  const cached = jwksCache.get(provider);
  if (cached && cached.expiresAt > nowMilliseconds) return cached.keys;

  const response = await fetchImpl(config.jwksURL, {
    headers: { Accept: "application/json" },
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok) throw new Error("identity_provider_unavailable");
  const body = await response.text();
  if (Buffer.byteLength(body, "utf8") > MAX_JWKS_BYTES) throw new Error("invalid_identity_keys");
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    throw new Error("invalid_identity_keys");
  }
  if (!Array.isArray(parsed?.keys) || parsed.keys.length < 1 || parsed.keys.length > 20) {
    throw new Error("invalid_identity_keys");
  }
  const maxAge = Number(response.headers.get("cache-control")?.match(/max-age=(\d+)/i)?.[1] ?? 300);
  const ttl = Math.min(3_600, Math.max(60, Number.isFinite(maxAge) ? maxAge : 300));
  jwksCache.set(provider, { keys: parsed.keys, expiresAt: nowMilliseconds + ttl * 1_000 });
  return parsed.keys;
}

export async function verifyIdentityToken({
  provider,
  token,
  audience,
  expectedNonce,
  nowSeconds = Math.floor(Date.now() / 1_000),
  fetchImpl = fetch,
}) {
  const config = IDENTITY_PROVIDERS[provider];
  if (!config || typeof audience !== "string" || !audience) throw new Error("identity_auth_not_configured");
  const jwt = parseJWT(token);
  if (jwt.header?.alg !== config.algorithm || typeof jwt.header?.kid !== "string") throw new Error("invalid_identity_token");
  const keys = await loadJWKS(provider, fetchImpl, nowSeconds * 1_000);
  const jwk = keys.find((key) => key?.kid === jwt.header.kid && key?.use !== "enc");
  if (!jwk) throw new Error("unknown_identity_key");

  let validSignature = false;
  try {
    const publicKey = createPublicKey({ key: jwk, format: "jwk" });
    const verifyOptions = provider === "apple"
      ? { key: publicKey, dsaEncoding: "ieee-p1363" }
      : publicKey;
    validSignature = verifySignature(
      "sha256",
      Buffer.from(jwt.signingInput, "utf8"),
      verifyOptions,
      jwt.signature,
    );
  } catch {
    throw new Error("invalid_identity_signature");
  }
  if (!validSignature) throw new Error("invalid_identity_signature");

  const payload = jwt.payload;
  const issuers = Array.isArray(config.issuer) ? config.issuer : [config.issuer];
  const audiences = Array.isArray(payload?.aud) ? payload.aud : [payload?.aud];
  if (!issuers.includes(payload?.iss)
    || !audiences.includes(audience)
    || (audiences.length > 1 && payload?.azp !== audience)
    || !Number.isFinite(payload?.exp)
    || payload.exp <= nowSeconds
    || !Number.isFinite(payload?.iat)
    || payload.iat > nowSeconds + 300
    || typeof payload?.sub !== "string"
    || payload.sub.length < 1
    || payload.sub.length > 255) {
    throw new Error("invalid_identity_claims");
  }
  if (typeof expectedNonce !== "string" || expectedNonce.length < 1 || payload.nonce !== expectedNonce) {
    throw new Error("invalid_identity_nonce");
  }
  return { subject: payload.sub };
}

export function makeUserSubject(secret, provider, providerSubject) {
  return createHmac("sha256", secret)
    .update(`quota:${provider}:${providerSubject}`)
    .digest("hex");
}

export function issueSessionToken(secret, subject, nowSeconds = Math.floor(Date.now() / 1_000)) {
  const issuedAt = nowSeconds;
  const expiresAt = issuedAt + SESSION_TTL_SECONDS;
  const header = Buffer.from(JSON.stringify({ alg: "HS256", typ: "JWT" })).toString("base64url");
  const payload = Buffer.from(JSON.stringify({
    iss: SESSION_ISSUER,
    aud: SESSION_AUDIENCE,
    sub: subject,
    iat: issuedAt,
    exp: expiresAt,
  })).toString("base64url");
  const input = `${header}.${payload}`;
  const signature = createHmac("sha256", secret).update(input).digest("base64url");
  return { sessionToken: `${input}.${signature}`, expiresAt };
}

export function verifySessionToken(secret, token, nowSeconds = Math.floor(Date.now() / 1_000)) {
  const jwt = parseJWT(token);
  if (jwt.header?.alg !== "HS256" || jwt.header?.typ !== "JWT") throw new Error("invalid_session");
  const expected = createHmac("sha256", secret).update(jwt.signingInput).digest();
  if (jwt.signature.length !== expected.length || !timingSafeEqual(jwt.signature, expected)) {
    throw new Error("invalid_session_signature");
  }
  const payload = jwt.payload;
  if (payload?.iss !== SESSION_ISSUER
    || payload?.aud !== SESSION_AUDIENCE
    || typeof payload?.sub !== "string"
    || payload.sub.length !== 64
    || !Number.isFinite(payload?.exp)
    || payload.exp <= nowSeconds
    || !Number.isFinite(payload?.iat)
    || payload.iat > nowSeconds + 300) {
    throw new Error("invalid_session_claims");
  }
  return { subject: payload.sub, expiresAt: payload.exp };
}
