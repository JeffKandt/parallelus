PY_ADAPTER_DIR := $(AGENTS_DIR)/adapters/python

.PHONY: python-lint python-format python-test

python-lint:
	@$(PY_ADAPTER_DIR)/lint.sh

python-format:
	@$(PY_ADAPTER_DIR)/format.sh

python-test:
	@$(PY_ADAPTER_DIR)/test.sh

lint:: python-lint

format:: python-format

test:: python-test

ci:: python-lint python-test
