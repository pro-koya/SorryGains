import { asc } from "./asc.mjs";
const APP = "6763986050";
const RS = "cc3bdc46-a21a-4084-a511-9cd5b35d6919";
const SUBS = ["6780126689", "6780126744"];

// Poll until the canceled review submission leaves an open state
for (let i = 0; i < 20; i++) {
  const r = await asc("GET", `/v1/reviewSubmissions/${RS}?fields[reviewSubmissions]=state`);
  const st = r.json?.data?.attributes?.state;
  const open = await asc("GET", `/v1/reviewSubmissions?filter[app]=${APP}&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES,CANCELING&limit=10`);
  const openCount = (open.json?.data || []).length;
  console.log(`poll ${i}: reviewSub state=${st}, open submissions=${openCount}`);
  if (st === "COMPLETE" && openCount === 0) break;
  await new Promise((res) => setTimeout(res, 3000));
}

// Recheck states
console.log("\n=== STATES ===");
for (const id of SUBS) {
  const s = await asc("GET", `/v1/subscriptions/${id}?fields[subscriptions]=state`);
  console.log(`SUB ${id} state=${s.json?.data?.attributes?.state}`);
  const locs = await asc("GET", `/v1/subscriptions/${id}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`);
  console.log("   locs:", (locs.json.data || []).map((l) => `${l.id} ${l.attributes.locale}:${l.attributes.state}`).join("  "));
}

// Probe: is a REJECTED localization PATCH-able now? (try a no-op-ish patch on monthly ja)
const probeLoc = "c182092f-680b-4fa4-8bd3-707c5c9053f9"; // monthly ja
const patch = await asc("PATCH", `/v1/subscriptionLocalizations/${probeLoc}`, {
  data: { type: "subscriptionLocalizations", id: probeLoc, attributes: { description: "3アプリのPro機能をまとめて解放（月額）" } },
});
console.log("\nPATCH probe on REJECTED loc:", patch.status, JSON.stringify(patch.json?.errors?.[0]?.code || patch.json?.data?.attributes?.state));
