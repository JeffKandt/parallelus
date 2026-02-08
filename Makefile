# Makefile for agent-process-demo

# >>> agent-process integration >>>
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
AGENTS_DIR ?= $(ROOT)/parallelus/engine
LANG_ADAPTERS ?= python

include $(AGENTS_DIR)/make/agents.mk
ifneq (,$(findstring python,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/python.mk
endif

ifneq (,$(findstring swift,$(LANG_ADAPTERS)))
include $(AGENTS_DIR)/make/swift.mk
endif

# <<< agent-process integration <<<

REMEMBER_LATER_SCRIPT := scripts/remember_later.py
CAPSULE_PROMPT_SCRIPT := scripts/capsule_prompt.py

.PHONY: help setup remember_later capsule_prompt

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
	@echo "  make remember_later m=\"Capture exploratory insight\" [topic=research] [next_step=run+spike]"
	@echo "  make capsule_prompt [session=20251025-123456] [file=parallelus/manuals/capsules/...md] [stub=1]"

setup:
	@echo "Customize this target for project-specific setup"

remember_later:
	@if [ -z "$(strip $(m))" ]; then \
		echo "Usage: make remember_later m=\"<message>\" [topic=\"<topic>\"] [next_step=\"<follow-up>\"] [tags=\"tag1 tag2\"] [file=\"path\"]"; \
		exit 1; \
	fi
	@python $(REMEMBER_LATER_SCRIPT) --message "$(m)" \
		$(if $(topic),--topic "$(topic)",) \
		$(if $(next_step),--next-step "$(next_step)",) \
	$(foreach tag,$(tags),--tag "$(tag)") \
	$(if $(file),--capsule-file "$(file)",)

capsule_prompt:
	@python $(CAPSULE_PROMPT_SCRIPT) \
	$(if $(file),--capsule-path "$(file)",) \
	$(if $(plan_slug),--plan-slug "$(plan_slug)",) \
	$(if $(session),--session-marker "$(session)",) \
	$(if $(tokens),--token-budget "$(tokens)",) \
	$(if $(reminders),--reminder-path "$(reminders)",) \
	$(if $(stub),--write-stub,) \
	$(if $(version),--version "$(version)",)
