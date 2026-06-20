import { asc } from "./asc.mjs";
const APP = "6763986050";
const RS = "cc3bdc46-a21a-4084-a511-9cd5b35d6919";
const SUBS = ["6780126689", "6780126744"];

// 1. Preserve current localization content
console.log("=== CURRENT LOCALIZATION CONTENT (preserve) ===");
for (const id of SUBS) {
  const locs = await asc("GET", `/v1/subscriptions/${id}/subscriptionLocalizations?limit=10`);
  for (const l of locs.json.data || []) {
    const a = l.attributes;
    console.log(`SUB ${id} loc ${l.id} ${a.locale} state=${a.state}`);
    console.log(`   name=${JSON.stringify(a.name)}`);
    console.log(`   desc=${JSON.stringify(a.description)}`);
  }
}

// 2. Cancel the UNRESOLVED_ISSUES review submission to unlock editing
console.log("\n=== CANCEL REVIEW SUBMISSION ===");
const cancel = await asc("PATCH", `/v1/reviewSubmissions/${RS}`, {
  data: { type: "reviewSubmissions", id: RS, attributes: { canceled: true } },
});
console.log("cancel status:", cancel.status, JSON.stringify(cancel.json?.errors || cancel.json?.data?.attributes?.state));

// 3. Re-check states after cancel
console.log("\n=== STATES AFTER CANCEL ===");
for (const id of SUBS) {
  const s = await asc("GET", `/v1/subscriptions/${id}?fields[subscriptions]=state,productId`);
  console.log(`SUB ${id} state=${s.json?.data?.attributes?.state}`);
  const img = await asc("GET", `/v1/subscriptions/${id}/images?limit=5`);
  for (const im of img.json.data || []) console.log(`   image ${im.id} state=${im.attributes.state}`);
  const locs = await asc("GET", `/v1/subscriptions/${id}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`);
  console.log("   locs:", (locs.json.data || []).map((l) => `${l.attributes.locale}:${l.attributes.state}`).join(", "));
}
const ver = await asc("GET", `/v1/appStoreVersions/9437d171-2599-4ce9-938b-44826960f6eb?fields[appStoreVersions]=appStoreState`);
console.log("version 1.0.2 state:", ver.json?.data?.attributes?.appStoreState);
