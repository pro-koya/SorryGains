import { asc } from "./asc.mjs";
const SUB = "6780126689";
const EN = { id: "ddf38228-063f-49a9-80bb-7caa51b5b394", locale: "en-US", name: "Muscle360 Pro (Monthly)", description: "Unlock Pro across all 3 Muscle360 apps." };
const JA = { id: "c182092f-680b-4fa4-8bd3-707c5c9053f9", locale: "ja", name: "Muscle360 Pro（月額）", description: "3アプリのPro機能をまとめて解放（月額）" };

async function del(id, label){ const r = await asc("DELETE", `/v1/subscriptionLocalizations/${id}`); console.log(`DELETE ${label}: ${r.status} ${r.ok?'':JSON.stringify(r.json?.errors?.[0]?.code||r.json?.errors)}`); return r; }
async function create(l){ const r = await asc("POST", "/v1/subscriptionLocalizations", { data:{ type:"subscriptionLocalizations", attributes:{ name:l.name, locale:l.locale, description:l.description }, relationships:{ subscription:{ data:{ type:"subscriptions", id:SUB }}}}}); console.log(`CREATE ${l.locale}: ${r.status} ${r.ok?r.json.data.id+' '+r.json.data.attributes.state:JSON.stringify(r.json?.errors)}`); return r; }
async function show(){ const locs = await asc("GET", `/v1/subscriptions/${SUB}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`); console.log("  -> locs:", (locs.json.data||[]).map(l=>`${l.attributes.locale}:${l.attributes.state}`).join(", ")); }

await del(EN.id, "en-US (both REJ)"); await show();
await create(EN); await show();
await del(JA.id, "ja (sibling now PREPARE -> mixed?)"); await show();
