import { asc } from "./asc.mjs";
import { replaceSubscriptionImage } from "./img.mjs";
const SUB = "6780126689"; // monthly
const OLD_IMG = "859d714c-6915-4935-9306-22d16b3e3a94";
const FILE = "/Users/koya1104/Desktop/01_active/Muscle360/SorryGains/ref-images/promo/pro_monthly_1024.png";

console.log("=== replace monthly image ===");
const newId = await replaceSubscriptionImage(SUB, OLD_IMG, FILE, "pro_monthly_1024.png");
console.log("new image id:", newId);

// re-check image state
const img = await asc("GET", `/v1/subscriptions/${SUB}/images?limit=5`);
for (const im of img.json.data || []) console.log("  image", im.id, "state", im.attributes.state);

// TEST: try subscriptionSubmissions with REJECTED locs present
console.log("\n=== try subscriptionSubmissions (with REJECTED locs) ===");
const sub = await asc("POST", "/v1/subscriptionSubmissions", {
  data: { type: "subscriptionSubmissions", relationships: { subscription: { data: { type: "subscriptions", id: SUB } } } },
});
console.log("subscriptionSubmissions:", sub.status, JSON.stringify(sub.json?.errors || sub.json?.data?.id));
const s = await asc("GET", `/v1/subscriptions/${SUB}?fields[subscriptions]=state`);
console.log("sub state now:", s.json?.data?.attributes?.state);
