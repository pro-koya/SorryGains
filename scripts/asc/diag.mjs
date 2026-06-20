import { asc } from "./asc.mjs";
const APP = "6763986050";

const groups = await asc("GET", `/v1/apps/${APP}/subscriptionGroups?include=subscriptions&limit=50`);
const included = groups.json.included || [];
console.log("=== SUBSCRIPTIONS ===");
const subs = included.filter((i) => i.type === "subscriptions");
for (const s of subs) {
  console.log(`SUB ${s.id} product=${s.attributes.productId} state=${s.attributes.state} name="${s.attributes.name}"`);
}
console.log("\n=== SUBSCRIPTION IMAGES + LOCALIZATIONS ===");
for (const s of subs) {
  const img = await asc("GET", `/v1/subscriptions/${s.id}/images?limit=10`);
  for (const im of img.json.data || []) {
    const a = im.attributes;
    console.log(`SUB ${s.id} image ${im.id} state=${a.state} fileName=${a.fileName} ${a.imageAsset?.width}x${a.imageAsset?.height}`);
  }
  if (!(img.json.data || []).length) console.log(`SUB ${s.id} image: NONE (status ${img.status})`);
  const locs = await asc("GET", `/v1/subscriptions/${s.id}/subscriptionLocalizations?limit=10`);
  const ls = (locs.json.data || []).map((l) => `${l.attributes.locale}:${l.attributes.state}`).join(", ");
  console.log(`SUB ${s.id} locs=[${ls}]`);
}

console.log("\n=== VERSIONS ===");
const vers = await asc("GET", `/v1/apps/${APP}/appStoreVersions?limit=4&fields[appStoreVersions]=versionString,appStoreState,appVersionState`);
for (const v of vers.json.data || []) {
  console.log(`VER ${v.id} ${v.attributes.versionString} state=${v.attributes.appStoreState}/${v.attributes.appVersionState}`);
}

console.log("\n=== OPEN REVIEW SUBMISSIONS ===");
const rs = await asc("GET", `/v1/reviewSubmissions?filter[app]=${APP}&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&limit=10&include=items`);
for (const r of rs.json.data || []) {
  console.log(`REVIEW_SUB ${r.id} state=${r.attributes.state}`);
}
if (!(rs.json.data || []).length) console.log("(none)");
