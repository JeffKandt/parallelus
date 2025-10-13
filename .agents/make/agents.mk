MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

AGENTS_DIR ?= $(abspath .agents)
AGENTS_BIN := $(AGENTS_DIR)/bin
PLAN_DIR ?= docs/plans
PROGRESS_DIR ?= docs/progress
SESSION_DIR ?= sessions

.PHONY: read_bootstrap bootstrap start_session turn_end archive agents-smoke agents-monitor-loop merge monitor_subagents

read_bootstrap:
	@if [ -z "$${PARALLELUS_SUPPRESS_TMUX_EXPORT:-}" ] && command -v tmux >/dev/null 2>&1; then \
		tmux_args=""; \
		if [ -n "$${PARALLELUS_TMUX_SOCKET:-}" ] && [ -S "$${PARALLELUS_TMUX_SOCKET}" ]; then \
			tmux_args="-S $${PARALLELUS_TMUX_SOCKET}"; \
		fi; \
		tmux $$tmux_args has-session >/dev/null 2>&1 && tmux $$tmux_args source-file .agents/tmux/parallelus-status.tmux >/dev/null 2>&1 || true; \
		tmux_env="$$({ command -v tmux >/dev/null 2>&1 && tmux $$tmux_args display-message -p '#{socket_path},#{session_id},#{pane_id}' ; } 2>/dev/null)"; \
		if [ -n "$$tmux_env" ]; then \
			export TMUX="$$tmux_env"; \
			tmux $$tmux_args set-environment -g TMUX "$$tmux_env" >/dev/null 2>&1 || true; \
		fi; \
	fi
	@$(AGENTS_BIN)/agents-detect

bootstrap:
ifndef slug
	$(error slug= is required, e.g. make bootstrap slug=my-feature)
endif
	@$(AGENTS_BIN)/agents-ensure-feature $(slug)

start_session:
	@eval "$$($(AGENTS_BIN)/agents-session-start)"

turn_end:
	@$(AGENTS_BIN)/verify-retrospective
	@$(AGENTS_BIN)/agents-turn-end "${m}"

archive:
ifndef b
	$(error b=branch-name is required, e.g. make archive b=feature/foo)
endif
	@$(AGENTS_BIN)/agents-archive-branch $(b)

agents-smoke: agents-monitor-loop
	@$(AGENTS_DIR)/tests/smoke.sh

agents-monitor-loop:
	@$(AGENTS_DIR)/tests/monitor_loop.py

merge:
ifndef slug
	$(error slug= is required, e.g. make merge slug=my-feature)
endif
	@$(AGENTS_BIN)/agents-merge $(slug)

monitor_subagents:
ifdef ARGS
	@$(AGENTS_BIN)/agents-monitor-loop.sh $(ARGS)
else
	@$(AGENTS_BIN)/agents-monitor-loop.sh --interval 45 --threshold 180 --runtime-threshold 600
endif

ifeq ($(strip $(LANG_ADAPTERS)),)
.PHONY: ci
ci:
	@echo "ci: no adapters enabled" >&2
else
ci:: agents-smoke
endif
