# App Store Privacy Notes

This note mirrors the current SorryGains implementation for App Store Connect privacy answers.

## Data Stored Only On Device

- Drinking records
- Body weight
- Weekly training frequency
- Recovery action completion
- Onboarding and display preferences

These are stored locally with SwiftData/UserDefaults and are not uploaded by SorryGains.

## Data Used When The User Links Liftly

Liftly linking is optional. When enabled, the app uses Apple/Google/Supabase authentication and fetches a Liftly training summary for app functionality.

Declare the following in App Store Connect if Liftly linking remains enabled:

| Category | Data Type | Linked to User | Tracking | Purpose |
| --- | --- | --- | --- | --- |
| Contact Info | Email Address | Yes | No | App Functionality |
| Identifiers | User ID | Yes | No | App Functionality |
| Health and Fitness | Fitness | Yes | No | App Functionality |

AdMob is now integrated for ads. Before release, review the Google Mobile Ads SDK privacy manifest in Xcode's generated privacy report and update App Store Connect answers for third-party advertising data as required by the report and the selected AdMob personalization/consent settings.

## Privacy Manifest Alignment

`SorryGains/Resources/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyCollectedDataTypeEmailAddress`
- `NSPrivacyCollectedDataTypeUserID`
- `NSPrivacyCollectedDataTypeFitness`
- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

Third-party SDKs such as GoogleSignIn, Supabase, and Google Mobile Ads also include their own privacy manifests in their packages. Review Xcode's generated privacy report before upload.

AdMob setup notes:

- `GADApplicationIdentifier` is set to `ca-app-pub-4570439660764279~1523718276`.
- Debug builds use Google's iOS test ad unit IDs.
- Release builds use the production Banner ad unit ID `ca-app-pub-4570439660764279/6162320951`.
- Release builds use the production Rewarded ad unit ID `ca-app-pub-4570439660764279/1715289963`.
- Keep `app-ads.txt` and the App Store marketing/support URL aligned before production ad serving.
