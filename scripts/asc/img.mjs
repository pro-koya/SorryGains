import { asc } from "./asc.mjs";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";

// Replace a subscription's promotional image: delete old -> reserve -> PUT bytes -> commit.
export async function replaceSubscriptionImage(subId, oldImageId, filePath, fileName) {
  const bytes = readFileSync(filePath);
  const md5 = createHash("md5").update(bytes).digest("hex");

  if (oldImageId) {
    const del = await asc("DELETE", `/v1/subscriptionImages/${oldImageId}`);
    console.log(`  DELETE old image ${oldImageId}: ${del.status}`);
  }

  // Reserve
  const reserve = await asc("POST", "/v1/subscriptionImages", {
    data: {
      type: "subscriptionImages",
      attributes: { fileName, fileSize: bytes.length },
      relationships: { subscription: { data: { type: "subscriptions", id: subId } } },
    },
  });
  if (!reserve.ok) {
    console.log(`  RESERVE failed ${reserve.status}:`, JSON.stringify(reserve.json?.errors));
    return null;
  }
  const imageId = reserve.json.data.id;
  const ops = reserve.json.data.attributes.uploadOperations || [];
  console.log(`  reserved image ${imageId}, ${ops.length} upload op(s)`);

  // Upload bytes per operation (signed URLs — raw fetch, no ASC auth)
  for (const op of ops) {
    const slice = bytes.subarray(op.offset || 0, (op.offset || 0) + op.length);
    const headers = {};
    for (const h of op.requestHeaders || []) headers[h.name] = h.value;
    const put = await fetch(op.url, { method: op.method || "PUT", headers, body: slice });
    console.log(`  PUT ${op.length}B -> ${put.status}`);
    if (!put.ok) { console.log("  upload op failed:", await put.text()); return null; }
  }

  // Commit
  const commit = await asc("PATCH", `/v1/subscriptionImages/${imageId}`, {
    data: {
      type: "subscriptionImages",
      id: imageId,
      attributes: { uploaded: true, sourceFileChecksum: md5 },
    },
  });
  console.log(`  COMMIT ${imageId}: ${commit.status} state=${commit.json?.data?.attributes?.state || JSON.stringify(commit.json?.errors)}`);
  return commit.ok ? imageId : null;
}
