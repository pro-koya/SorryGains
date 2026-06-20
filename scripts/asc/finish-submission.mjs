import { asc } from "./asc.mjs";
// Run AFTER the 2 ja localizations are cleared to PREPARE via ASC Web UI.
//   node finish-submission.mjs          -> verify + assemble (no submit)
//   node finish-submission.mjs submit   -> verify + assemble + SUBMIT for review
const APP = "6763986050";
const VER = "9437d171-2599-4ce9-938b-44826960f6eb";
const SUBS = ["6780126689", "6780126744"];
const DO_SUBMIT = process.argv.includes("submit");

// 1. Guard: every localization must be PREPARE_FOR_SUBMISSION (no REJECTED left)
let blocked = false;
for (const id of SUBS) {
  const locs = await asc("GET", `/v1/subscriptions/${id}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`);
  for (const l of locs.json.data || []) {
    const ok = l.attributes.state === "PREPARE_FOR_SUBMISSION" || l.attributes.state === "WAITING_FOR_REVIEW" || l.attributes.state === "APPROVED";
    if (!ok) { console.log(`BLOCKED: SUB ${id} ${l.attributes.locale} is ${l.attributes.state} (fix via ASC Web UI first)`); blocked = true; }
  }
}
if (blocked) { console.log("\nAborting — clear the REJECTED localization(s) in ASC Web UI, then re-run."); process.exit(1); }
console.log("All localizations OK.");

// 2. Submit each subscription (image + locs) for review (skip if already in review)
for (const id of SUBS) {
  let s = await asc("GET", `/v1/subscriptions/${id}?fields[subscriptions]=state`);
  if (s.json?.data?.attributes?.state !== "WAITING_FOR_REVIEW") {
    const r = await asc("POST", "/v1/subscriptionSubmissions", {
      data: { type: "subscriptionSubmissions", relationships: { subscription: { data: { type: "subscriptions", id } } } },
    });
    console.log(`subscriptionSubmissions ${id}: ${r.status} ${r.json?.errors ? JSON.stringify(r.json.errors) : ""}`);
    s = await asc("GET", `/v1/subscriptions/${id}?fields[subscriptions]=state`);
  }
  console.log(`   SUB ${id} -> ${s.json?.data?.attributes?.state}`);
}

// 3. Create review submission + add the version item
const rs = await asc("POST", "/v1/reviewSubmissions", {
  data: { type: "reviewSubmissions", attributes: { platform: "IOS" }, relationships: { app: { data: { type: "apps", id: APP } } } },
});
const rsId = rs.json?.data?.id;
console.log("reviewSubmission:", rs.status, rsId);
const item = await asc("POST", "/v1/reviewSubmissionItems", {
  data: { type: "reviewSubmissionItems", relationships: {
    reviewSubmission: { data: { type: "reviewSubmissions", id: rsId } },
    appStoreVersion: { data: { type: "appStoreVersions", id: VER } } } },
});
console.log("add version item:", item.status, item.json?.errors ? JSON.stringify(item.json.errors) : "ok");

// 4. Submit (only with explicit flag)
if (DO_SUBMIT) {
  const sub = await asc("PATCH", `/v1/reviewSubmissions/${rsId}`, {
    data: { type: "reviewSubmissions", id: rsId, attributes: { submitted: true } },
  });
  console.log("SUBMIT:", sub.status, JSON.stringify(sub.json?.data?.attributes || sub.json?.errors));
  const v = await asc("GET", `/v1/appStoreVersions/${VER}?fields[appStoreVersions]=appStoreState`);
  console.log("version final state:", v.json?.data?.attributes?.appStoreState);
} else {
  console.log(`\nAssembled reviewSubmission ${rsId} (NOT submitted). Re-run with 'submit' to finish.`);
}
