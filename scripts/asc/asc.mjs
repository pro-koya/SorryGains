#!/usr/bin/env node
// Minimal App Store Connect API client (ES256 JWT via Node crypto, no deps).
// Usage:
//   node asc.mjs GET  /v1/apps/6766134975
//   node asc.mjs POST /v1/path '<json-body>'
//   node asc.mjs PATCH /v1/path '<json-body>'
//   node asc.mjs DELETE /v1/path
import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";
import { homedir } from "node:os";

const cfg = JSON.parse(
  readFileSync(`${homedir()}/.appstoreconnect/asc_api_key.json`, "utf8")
);
const privateKey = readFileSync(cfg.key_filepath, "utf8");

function b64url(input) {
  return Buffer.from(input)
    .toString("base64")
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function makeJWT() {
  const header = { alg: "ES256", kid: cfg.key_id, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: cfg.issuer_id,
    iat: now,
    exp: now + 60 * 15,
    aud: "appstoreconnect-v1",
  };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(
    JSON.stringify(payload)
  )}`;
  const signer = createSign("SHA256");
  signer.update(signingInput);
  signer.end();
  // ASC requires raw R||S (P1363), not DER.
  const signature = signer.sign({ key: privateKey, dsaEncoding: "ieee-p1363" });
  return `${signingInput}.${b64url(signature)}`;
}

export async function asc(method, path, body) {
  const url = path.startsWith("http")
    ? path
    : `https://api.appstoreconnect.apple.com${path}`;
  const headers = { Authorization: `Bearer ${makeJWT()}` };
  let payload;
  if (body !== undefined && body !== null && body !== "") {
    headers["Content-Type"] = "application/json";
    payload = typeof body === "string" ? body : JSON.stringify(body);
  }
  const res = await fetch(url, { method, headers, body: payload });
  const text = await res.text();
  let json;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }
  return { status: res.status, ok: res.ok, json };
}

// CLI mode
if (import.meta.url === `file://${process.argv[1]}`) {
  const [, , method, path, bodyArg] = process.argv;
  if (!method || !path) {
    console.error("usage: node asc.mjs <METHOD> <path> [jsonBody]");
    process.exit(1);
  }
  const { status, json } = await asc(method.toUpperCase(), path, bodyArg);
  console.log(JSON.stringify({ status, json }, null, 2));
}
