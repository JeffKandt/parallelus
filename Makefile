# Makefile for agent-process-demo

# >>> agent-process integration >>>
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
AGENTS_DIR ?= $(ROOT)/.agents
LANG_ADAPTERS ?= python swift

include $(AGENTS_DIR)/make/agents.mk
ifneq (,$(findstring python,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/python.mk
endif

ifneq (,$(findstring swift,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/swift.mk
endif

# <<< agent-process integration <<<

.PHONY: help setup

help:
	@echo "agent-process-demo - Agent Process"
	@echo "=============================="
	@echo
	@echo "Primary commands:"
	@echo "  make read_bootstrap"
	@echo "  make bootstrap slug=my-feature"
	@echo "  make start_session"
	@echo "  make turn_end m=\"summary\""
	@echo "  make ci"
	@echo "  make merge slug=my-feature"

setup:
	@echo "Customize this target for project-specific setup"
