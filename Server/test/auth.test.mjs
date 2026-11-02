import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, sign } from "node:crypto";
import { test } from "node:test";
import { issueSessionToken, makeUserSubject, verifyIdentityToken, verifySessionToken } from "../src/auth.mjs";

const now = 1_800_000_000;
const base64url = (value) => Buffer.from(value).toString("base64url");

function makeIdentityJWT({ privateKey, algorithm, kid, payload }) {
  const header = base64url(JSON.stringify({ alg: algorithm, typ: "JWT", kid }));
  const body = base64url(JSON.stringify(payload));
  const input = `${header}.${body}`;
  const signature = algorithm === "ES256"
    ? sign("sha256", Buffer.from(input), { key: privateKey, dsaEncoding: "ieee-p1363" })
    : sign("sha256", Buffer.from(input), privateKey);
  return `${input}.${signature.toString("base64url")}`;
}

test("Node auth verifies Apple and Google JWTs against fake JWKS and signs scoped sessions", async () => {
  const applePair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const googlePair = generateKeyPairSync("rsa", { modulusLength: 2_048 });
  const appleKid = "apple-unit-test-key";
  const googleKid = "google-unit-test-key";
  const appleJWK = { ...applePair.publicKey.export({ format: "jwk" }), kid: appleKid, alg: "ES256", use: "sig" };
  const googleJWK = { ...googlePair.publicKey.export({ format: "jwk" }), kid: googleKid, alg: "RS256", use: "sig" };
  const jwks = new Map([
    ["https://appleid.apple.com/auth/keys", { keys: [appleJWK] }],
    ["https://www.googleapis.com/oauth2/v3/certs", { keys: [googleJWK] }],
  ]);
  const requestedURLs = [];
  const fakeFetch = async (url) => {
    requestedURLs.push(String(url));
    const payload = jwks.get(String(url));
    if (!payload) throw new Error("unexpected external fetch");
    return new Response(JSON.stringify(payload), {
      status: 200,
      headers: { "content-type": "application/json", "cache-control": "public, max-age=300" },
    });
  };

  const rawNonce = "d90a0f5f2e5d4a47a3c8fbc1e9f6d042";
  const hashedNonce = createHash("sha256").update(rawNonce).digest("hex");
  const appleToken = makeIdentityJWT({
    privateKey: applePair.privateKey,
    algorithm: "ES256",
    kid: appleKid,
    payload: {
      iss: "https://appleid.apple.com",
      aud: "com.charlie.pandaplate",
      sub: "apple-user-subject",
      iat: now - 10,
      exp: now + 300,
      nonce: hashedNonce,
    },
  });
  const appleIdentity = await verifyIdentityToken({
    provider: "apple",
    token: appleToken,
    audience: "com.charlie.pandaplate",
    expectedNonce: hashedNonce,
    nowSeconds: now,
    fetchImpl: fakeFetch,
  });
  assert.equal(appleIdentity.subject, "apple-user-subject");
  await assert.rejects(
    verifyIdentityToken({
      provider: "apple", token: appleToken, audience: "com.charlie.pandaplate",
      expectedNonce: "wrong-nonce", nowSeconds: now, fetchImpl: fakeFetch,
    }),
    /invalid_identity_nonce/,
  );

  const googleRawNonce = "google-server-nonce-value-12345678901234567890";
  const googleToken = makeIdentityJWT({
    privateKey: googlePair.privateKey,
    algorithm: "RS256",
    kid: googleKid,
    payload: {
      iss: "https://accounts.google.com",
      aud: "google-server-client-id.apps.googleusercontent.com",
      sub: "google-user-subject",
      iat: now - 10,
      exp: now + 300,
      nonce: googleRawNonce,
    },
  });
  const googleIdentity = await verifyIdentityToken({
    provider: "google",
    token: googleToken,
    audience: "google-server-client-id.apps.googleusercontent.com",
    expectedNonce: googleRawNonce,
    nowSeconds: now,
    fetchImpl: fakeFetch,
  });
  assert.equal(googleIdentity.subject, "google-user-subject");
  await assert.rejects(
    verifyIdentityToken({
      provider: "google", token: googleToken, audience: "google-server-client-id.apps.googleusercontent.com",
      expectedNonce: "wrong-google-nonce", nowSeconds: now, fetchImpl: fakeFetch,
    }),
    /invalid_identity_nonce/,
  );
  await assert.rejects(
    verifyIdentityToken({
      provider: "google", token: googleToken, audience: "google-server-client-id.apps.googleusercontent.com",
      nowSeconds: now, fetchImpl: fakeFetch,
    }),
    /invalid_identity_nonce/,
  );
  await assert.rejects(
    verifyIdentityToken({
      provider: "google", token: googleToken, audience: "wrong-audience",
      nowSeconds: now, fetchImpl: fakeFetch,
    }),
    /invalid_identity_claims/,
  );
  assert.deepEqual(requestedURLs.sort(), [
    "https://appleid.apple.com/auth/keys",
    "https://www.googleapis.com/oauth2/v3/certs",
  ]);

  const signingSecret = "unit-test-session-secret-with-more-than-32-characters";
  const userKey = makeUserSubject(signingSecret, "apple", appleIdentity.subject);
  const issued = issueSessionToken(signingSecret, userKey, now);
  assert.equal(verifySessionToken(signingSecret, issued.sessionToken, now).subject, userKey);
  assert.throws(() => verifySessionToken(signingSecret, `${issued.sessionToken.slice(0, -1)}x`, now));
  assert.throws(() => verifySessionToken(signingSecret, issued.sessionToken, issued.expiresAt));
});
