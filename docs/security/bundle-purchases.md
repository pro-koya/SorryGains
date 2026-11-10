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

全アプリのRelease build、既存全テスト、実機での購入・復元・返金・アカウント切替・家族共有の正常往復と画面確認は、この選択モジュール試験だけでは検証していない。App Storeへのupload、審査提出、公開は未実施。配布されるまで旧アプリの横断同期は再開しない。

リポジトリ全体で `xcodegen generate` を実行し、新しいCore/SubscriptionとTestsをプロジェクトへ取り込む。`project.yml`を正本とし、生成済みxcodeprojを手で編集しない。`xcodebuild -scheme SorryGains -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO -derivedDataPath ~/.cache/koya-build/SorryGains/security-release build` で署名なしビルドを検証後、既存リリース手順で署名/配布する。

参照: [Apple VerificationResult](https://developer.apple.com/documentation/storekit/verificationresult)、[Supabase Swift Functions](https://supabase.com/docs/reference/swift/functions-invoke)、[Flutter StoreKit JWS](https://pub.dev/packages/in_app_purchase_storekit/changelog)。
