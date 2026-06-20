import { asc } from "./asc.mjs";
const SUB = "6780126689";
const JA = "c182092f-680b-4fa4-8bd3-707c5c9053f9";
const EN_NEW = "9d8ee440-163f-4637-893b-c848ee98a2e4";

// Retry mixed delete (is the 500 flaky or structural?)
for (let i=0;i<3;i++){ const r = await asc("DELETE", `/v1/subscriptionLocalizations/${JA}`); console.log(`retry ${i} delete ja (sibling PREPARE): ${r.status} ${r.json?.errors?.[0]?.code||''}`); await new Promise(s=>setTimeout(s,2500)); }

// Now delete the PREPARE en-US so ja becomes the only/last loc, then test deleting ja (last)
const d = await asc("DELETE", `/v1/subscriptionLocalizations/${EN_NEW}`);
console.log(`delete en-US PREPARE: ${d.status}`);
const locs = await asc("GET", `/v1/subscriptions/${SUB}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`);
console.log("locs:", (locs.json.data||[]).map(l=>`${l.attributes.locale}:${l.attributes.state}`).join(", "));
const d2 = await asc("DELETE", `/v1/subscriptionLocalizations/${JA}`);
console.log(`delete ja (now last): ${d2.status} ${d2.json?.errors?.[0]?.code||''}`);
