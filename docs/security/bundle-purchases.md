# バンドル購入の検証と配布（2026-11-10）

購入端末のストア権利と、ログイン中の本人に属するアプリ間共有を分ける。自己申告の取引ID/期限を送る旧 `record_bundle_purchase` RPC と、端末から加入状態を書き換える経路は使わない。

- 新規バンドル購入はログイン後に開始し、Supabase UUIDをAppleのappAccountTokenへ渡す。
- `verify-bundle-purchase` Edgeへ、利用者のBearer sessionと `{bundleId, signedTransaction}` だけを送る。JWS/トークン/利用者ID/サーバー生エラーをログへ出さない。
- サーバー共有はProductionの購入だけが対象。署名・アプリ/商品・購入者・appAccountToken一致・Apple最新状態をサーバーで照合する。Sandbox/StoreKit Testは端末のローカル権利だけで検証する。
- tokenがない旧購入、別アカウント、家族共有は自動で紐付けない。端末の有効な購入は維持する。旧購入の共有には所有者を確認する別の移行手続きが必要で、復元だけではappAccountTokenが遡って付かない。取引IDだけで移管しない。
- サーバー共有は本人・有限期限付き。サーバーの期限はApple期限と再検証lease（最大30分）の短い方。アカウント変更/ログアウトで共有状態を破棄し、期限でも失効する。GET/POST共通の送信前世代により古い応答を破棄する。
- ローカルStoreKitは検証済みtransactionの期限を使う。AppleのinGracePeriodは同じoriginalIDの検証済みtransaction/renewalInfoからgracePeriodExpirationDateを取り、自己加算しない。サーバーのfalseで端末の有効な購入を消さない。

## 検証済み

- Supabase Swift 2.55.6と実際のStoreKitを使う選択モジュールのReleaseコンパイル（macOS 14 / arm64 iOS 17 SDK）。
- 権利分離、期限、アカウント切替、署名済み猶予期限の採用条件、遅着応答の拒否の単体試験10件。
- Appの認証UID監視変更はSwift構文解析。

## 配布前に残る確認

既存全テスト、実機での購入・復元・返金・アカウント切替・家族共有の正常往復と画面確認は、この選択モジュール試験だけでは検証していない。App Storeへのupload、審査提出、公開は未実施。配布されるまで旧アプリの横断同期は再開しない。

リポジトリ全体で `xcodegen generate` を実行し、新しいCore/SubscriptionとTestsをプロジェクトへ取り込む。`project.yml`を正本とし、生成済みxcodeprojを手で編集しない。`xcodebuild -scheme SorryGains -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath ~/.cache/koya-build/SorryGains/security-release build` で署名なしビルドを検証後、既存リリース手順で署名/配布する。

参照: [Apple VerificationResult](https://developer.apple.com/documentation/storekit/verificationresult)、[Supabase Swift Functions](https://supabase.com/docs/reference/swift/functions-invoke)、[Flutter StoreKit JWS](https://pub.dev/packages/in_app_purchase_storekit/changelog)。

## 署名なし全体ビルドの実測

2026-11-10、source main `5c3bf8aba66b2a55a362f5f03a3502837002cc1c` からXcodeGenで生成し、Xcode 27.2 / arm64 iOS / Release / CODE_SIGNING_ALLOWED=NOのアプリ全体buildが成功（BUILD SUCCEEDED）。新しいCore stateも含む。App Storeへのupload/審査/公開は行っていない。選択モジュールの各10試験も成功したが、アプリ全体の既存テスト・UI・実購入/復元の正常往復は未検証。

既存のCharacterSpeechView（Combineの直接import）、OnboardingContainerView（SwiftDataの直接import）、SageContextBuilder（非推奨initializer）のSwift警告、GoogleAds dSYM stubとAppIntentsの警告が残る。今回の購入state/managerにはコンパイル警告なし。tracked xcodeprojはXcodeGenで新しいstate/testの参照8行だけを追加し、手編集していない。

## 署名済み配布候補（未アップロード）

2026-11-10、既存のASC用キー・同じTeam設定を使い、署名付きarchiveとApp Store Connect向けIPAのローカルexportを完了。購入検証用SubscriptionKeyは配布に使用していない。

| Item | Value |
|---|---|
| Version / build | 1.0.3 / 9 |
| Source main | `340682d7356b32229245c7d7e014a1db9f204c72` |
| Archive | `/Users/koya1104/.cache/koya-build/sorrygains/security-release/SorryGains.xcarchive` |
| IPA | `/Users/koya1104/.cache/koya-build/sorrygains/security-release/appstore-export/SorryGains.ipa` |
| IPA SHA256 | `2d653c6082e4d3e1c3a6f60b54d24bd9e22655be9f63eb61ae80e553dd1ac244` |
| Minimum iOS | 17.0 |
| Signature | Apple Distribution / Team 992BWJ82JX |

archiveの既存開発署名をもとに、export時にIPAをApple Distributionへ再署名した。IPAを展開して `codesign --verify --deep --strict` とApple anchor/Team OU要件を確認。get-task-allow=false、App Store profile（端末リスト/全端末配布なし、beta-reports-active=true、有効期限内）、bundle ID・version/build・最低OSの一致を確認した。ExportOptionsはdestination=export、manageAppVersionAndBuildNumber=false。実機の正規購入/restore・更新/返金・アカウント切替の全通し、App Storeへのupload/審査/公開は未実施。

採用ログとexportのPackaging.logにJWTやprivate keyの値を残さない。Xcodeが内部配布ログへ自動記録する一時JWTも、終了直後に走査・伏字化した。archive/IPAはdisk-guardで消されないよう各フォルダに.disk-guard-keepを置き、公開が承認されるまで保持する。
