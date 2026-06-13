DEVICE ?= iPhone 16

.PHONY: run

run:
	./scripts/restart-simulator.sh "$(DEVICE)"
