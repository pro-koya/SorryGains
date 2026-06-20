import { asc } from "./asc.mjs";
const VER = "9437d171-2599-4ce9-938b-44826960f6eb";
const b = await asc("GET", `/v1/appStoreVersions/${VER}/build?fields[builds]=version,processingState,usesNonExemptEncryption`);
console.log("version build:", JSON.stringify(b.json?.data?.attributes), "id", b.json?.data?.id);
const v = await asc("GET", `/v1/appStoreVersions/${VER}?fields[appStoreVersions]=appStoreState,versionString`);
console.log("version:", JSON.stringify(v.json?.data?.attributes));
const app = await asc("GET", `/v1/apps/6763986050/appInfos?include=ageRatingDeclaration`);
for (const ai of app.json?.data||[]) console.log("appInfo", ai.id, "state", ai.attributes?.appStoreAgeRating || ai.attributes?.state);
