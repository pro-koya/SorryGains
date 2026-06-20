import { asc } from "./asc.mjs";
import { replaceSubscriptionImage } from "./img.mjs";
const SUB = "6780126744";
const OLD_IMG = "c0999ebc-b053-401b-bcd6-dfc2c284f025";
const FILE = "/Users/koya1104/Desktop/01_active/Muscle360/SorryGains/ref-images/promo/pro_yearly_1024.png";
const EN = { id: "57bf8f5d-1f7f-4c0c-b024-f9182a7fd380", locale: "en-US", name: "Muscle360 Pro (Annual)", description: "Unlock Pro in all 3 apps. Yearly plan." };

console.log("=== replace yearly image ===");
const newId = await replaceSubscriptionImage(SUB, OLD_IMG, FILE, "pro_yearly_1024.png");
console.log("new image id:", newId);

console.log("\n=== fix yearly en-US loc (delete REJ + recreate PREPARE) ===");
const d = await asc("DELETE", `/v1/subscriptionLocalizations/${EN.id}`);
console.log("delete en-US:", d.status);
const c = await asc("POST", "/v1/subscriptionLocalizations", { data:{ type:"subscriptionLocalizations", attributes:{ name:EN.name, locale:EN.locale, description:EN.description }, relationships:{ subscription:{ data:{ type:"subscriptions", id:SUB }}}}});
console.log("recreate en-US:", c.status, c.json?.data?.attributes?.state || JSON.stringify(c.json?.errors));

console.log("\n=== final loc/image state for BOTH subs ===");
for (const id of ["6780126689","6780126744"]) {
  const img = await asc("GET", `/v1/subscriptions/${id}/images?fields[subscriptionImages]=state&limit=3`);
  const locs = await asc("GET", `/v1/subscriptions/${id}/subscriptionLocalizations?fields[subscriptionLocalizations]=locale,state`);
  console.log(`SUB ${id}: image=${(img.json.data||[]).map(i=>i.attributes.state)} locs=[${(locs.json.data||[]).map(l=>`${l.attributes.locale}:${l.attributes.state}`).join(", ")}]`);
}
