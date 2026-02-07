SWIFT_ADAPTER_DIR := $(AGENTS_DIR)/adapters/swift

.PHONY: swift-lint swift-format swift-test

swift-lint:
	@$(SWIFT_ADAPTER_DIR)/lint.sh

swift-format:
	@$(SWIFT_ADAPTER_DIR)/format.sh

swift-test:
	@$(SWIFT_ADAPTER_DIR)/test.sh

lint:: swift-lint

format:: swift-format

test:: swift-test

ci:: swift-lint swift-test
