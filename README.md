# SorryGains

## Simulator

Restart the latest build in the iOS Simulator with one command:

```bash
./scripts/restart-simulator.sh
```

If you want to target a specific simulator device:

```bash
./scripts/restart-simulator.sh "iPhone 17 Pro"
```

You can also launch it with `make`:

```bash
make run
```

To target a specific simulator:

```bash
make run DEVICE="iPhone 17 Pro"
```


## バンドル購入のセキュリティ（2026-11-10）

署名済み購入証明とログインアカウントを照合する同期へ変更。端末購入とサーバー共有の権利を分けています。検証範囲・旧購入の移行制約・配布前の手順は [購入検証と配布](docs/security/bundle-purchases.md) を参照してください。App Storeへの公開はまだ行っていません。
