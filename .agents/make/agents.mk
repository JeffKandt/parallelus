MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

AGENTS_DIR ?= $(abspath .agents)
AGENTS_BIN := $(AGENTS_DIR)/bin
PLAN_DIR ?= docs/branches
PROGRESS_DIR ?= docs/branches
SESSION_DIR ?= .parallelus/sessions

.PHONY: read_bootstrap bootstrap start_session turn_end archive agents-smoke agents-monitor-loop merge monitor_subagents queue_init queue_show queue_pull queue_clear queue_path collect_failures

read_bootstrap:
	@if [ "$${AGENTS_SESSION_LOG_REQUIRED:-1}" != "0" ] && ! $(AGENTS_BIN)/agents-session-logging-active --quiet; then \
		echo "read_bootstrap: session logging is not active. Run: eval \"\$$\(make start_session\)\"" >&2; \
		exit 1; \
	fi
	@if [ -z "$${PARALLELUS_SUPPRESS_TMUX_EXPORT:-}" ] && command -v tmux >/dev/null 2>&1; then \
		tmux_args=""; \
		if [ -n "$${PARALLELUS_TMUX_SOCKET:-}" ] && [ -S "$${PARALLELUS_TMUX_SOCKET}" ]; then \
			tmux_args="-S $${PARALLELUS_TMUX_SOCKET}"; \
		fi; \
		tmux $$tmux_args has-session >/dev/null 2>&1 && tmux $$tmux_args source-file .agents/tmux/parallelus-status.tmux >/dev/null 2>&1 || true; \
		tmux_env=""; \
		tmux_env_raw="$$(tmux $$tmux_args show-environment -g TMUX 2>/dev/null || true)"; \
		if [ -n "$$tmux_env_raw" ] && [ "$$tmux_env_raw" != "no such variable" ]; then \
			tmux_env="$${tmux_env_raw#TMUX=}"; \
		else \
			tmux_control="$$(tmux $$tmux_args -C display-message -p '#{socket_path},#{session_id},#{pane_id}' 2>/dev/null || true)"; \
			if [ -n "$$tmux_control" ]; then \
				tmux_env="$$(printf '%s\n' \"$$tmux_control\" | awk 'NR==2 {print; exit}')"; \
			fi; \
		fi; \
		if [ -n "$$tmux_env" ]; then \
			export TMUX="$$tmux_env"; \
			tmux $$tmux_args set-environment -g TMUX "$$tmux_env" >/dev/null 2>&1 || true; \
		fi; \
	fi
	@$(AGENTS_BIN)/agents-detect
	@printf '\nBranch / PR snapshot:\n'; \
	$(AGENTS_BIN)/report_branches.py || true

bootstrap:
ifndef slug
	$(error slug= is required, e.g. make bootstrap slug=my-feature)
endif
	@$(AGENTS_BIN)/agents-ensure-feature $(slug)

start_session:
	@$(AGENTS_BIN)/agents-session-start

turn_end:
	@$(AGENTS_BIN)/agents-turn-end "${m}"

collect_failures:
	@$(AGENTS_BIN)/collect_failures.py

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

MONITOR_DEFAULT_FLAGS=--interval 10 --threshold 30 --runtime-threshold 600

monitor_subagents:
ifdef ARGS
	@$(AGENTS_BIN)/agents-monitor-loop.sh $(MONITOR_DEFAULT_FLAGS) $(ARGS)
else
	@$(AGENTS_BIN)/agents-monitor-loop.sh $(MONITOR_DEFAULT_FLAGS)
endif

queue_init:
	@$(AGENTS_BIN)/branch-queue init

queue_show:
	@$(AGENTS_BIN)/branch-queue show

queue_pull:
	@$(AGENTS_BIN)/branch-queue pull

queue_clear:
	@$(AGENTS_BIN)/branch-queue clear

queue_path:
	@$(AGENTS_BIN)/branch-queue path

ifeq ($(strip $(LANG_ADAPTERS)),)
.PHONY: ci
ci:
	@echo "ci: no adapters enabled" >&2
else
ci:: agents-smoke
endif
