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
