import { asc } from "./asc.mjs";
const YJA = "63d5ff33-7a36-4a36-8bc9-e208fb9c0627"; // yearly ja REJECTED (en-US sibling PREPARE, no pending subscriptionSubmission)
const r = await asc("DELETE", `/v1/subscriptionLocalizations/${YJA}`);
console.log("delete yearly ja:", r.status, r.json?.errors?.[0]?.code || "(ok)");

// Also: is there a deletable subscriptionSubmission on monthly we can remove to unwedge?
const MSUB = "6780126689";
const subs = await asc("GET", `/v1/subscriptions/${MSUB}/subscriptionSubmissions?limit=5`).catch(()=>null);
console.log("monthly subscriptionSubmissions endpoint:", subs?.status, JSON.stringify(subs?.json?.data?.map(d=>({id:d.id,state:d.attributes?.state})) || subs?.json?.errors?.[0]?.code));
