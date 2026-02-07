#!/usr/bin/env bash
# Deploy the Parallelus agent process to a target repository.
# Supports scaffolding new repositories or overlaying onto existing ones.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

DEFAULT_PROJECT_NAME="agent-process-demo"
DEFAULT_BASE_BRANCH="main"
DEFAULT_LANGS="python"

PROJECT_NAME="$DEFAULT_PROJECT_NAME"
BASE_BRANCH="$DEFAULT_BASE_BRANCH"
REMOTE_URL=""
TARGET_DIR=""
LANGS=""
MODE="scaffold"
VERIFY=0
FORCE=0
OVERLAY_BACKUP=1
OVERLAY_UPGRADE=0
DETECT_NAMESPACE_ONLY=0

NAMESPACE_DECISION=""
NAMESPACE_REASON=""
NAMESPACE_OVERRIDE_USED=0
NAMESPACE_PARALLELUS_SENTINEL="missing"
NAMESPACE_VENDOR_SENTINEL="missing"
NAMESPACE_STRONG_COUNT=0
NAMESPACE_CONTEXT_COUNT=0
declare -a NAMESPACE_STRONG_MATCHES=()
declare -a NAMESPACE_CONTEXT_MATCHES=()

usage() {
    cat <<'USAGE'
Usage: .agents/bin/deploy_agents_process.sh [OPTIONS] TARGET_DIRECTORY

Options:
  -n, --name NAME        Project name (default: agent-process-demo)
  -b, --base BRANCH      Base branch name (default: main)
  -r, --remote URL       Remote repository URL to configure
      --lang LANG        Language overlay (python, swift). Repeat to add more.
      --mode MODE        Deployment mode: scaffold (default) or overlay
      --verify           Run bootstrap + smoke verification (scaffold only)
      --force            Allow non-empty targets (scaffold) or dirty trees (overlay)
      --overlay-no-backup
                         Skip creating .bak backups during overlay (use with caution)
      --overlay-upgrade  Overlay shortcut: implies --mode overlay, enforces clean target, and disables .bak backups
      --detect-namespace
                         Print namespace detection decision for TARGET_DIRECTORY and exit
  -h, --help             Show this message

Examples:
  .agents/bin/deploy_agents_process.sh ./new-repo
  .agents/bin/deploy_agents_process.sh --name my-app --lang swift ./swift-repo
  .agents/bin/deploy_agents_process.sh --mode overlay --lang python ../existing
  .agents/bin/deploy_agents_process.sh --detect-namespace ../existing
USAGE
}

fail() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

warn() {
    echo -e "${YELLOW}$1${NC}" >&2
}

add_language() {
    local lang="$1"
    case "$lang" in
        python|swift) ;;
        *) fail "Unsupported language overlay: $lang" ;;
    esac

    if [[ -z "$LANGS" ]]; then
        LANGS="$lang"
    else
        case " $LANGS " in
            *" $lang "*) ;;
            *) LANGS="$LANGS $lang" ;;
        esac
    fi
}

absolute_path() {
    local path="$1"
    if [[ "$path" == /* ]]; then
        printf '%s\n' "$path"
    else
        local dir name
        dir="$(cd "$(dirname "$path")" && pwd)" || return 1
        name="$(basename "$path")"
        printf '%s/%s\n' "$dir" "$name"
    fi
}

is_truthy() {
    case "${1:-}" in
        1|true|TRUE|yes|YES|on|ON) return 0 ;;
        *) return 1 ;;
    esac
}

join_csv() {
    if [[ $# -eq 0 ]]; then
        printf '%s\n' "-"
        return
    fi
    local IFS=','
    printf '%s\n' "$*"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n|--name)
                [[ $# -lt 2 ]] && fail "Missing value for $1"
                PROJECT_NAME="$2"
                shift 2
                ;;
            -b|--base)
                [[ $# -lt 2 ]] && fail "Missing value for $1"
                BASE_BRANCH="$2"
                shift 2
                ;;
            -r|--remote)
                [[ $# -lt 2 ]] && fail "Missing value for $1"
                REMOTE_URL="$2"
                shift 2
                ;;
            --lang)
                [[ $# -lt 2 ]] && fail "Missing value for --lang"
                add_language "$2"
                shift 2
                ;;
            --mode)
                [[ $# -lt 2 ]] && fail "Missing value for --mode"
                MODE="$2"
                if [[ "$MODE" != "scaffold" && "$MODE" != "overlay" ]]; then
                    fail "--mode must be scaffold or overlay"
                fi
                shift 2
                ;;
            --verify)
                VERIFY=1
                shift
                ;;
            --force)
                FORCE=1
                shift
                ;;
            --overlay-no-backup)
                OVERLAY_BACKUP=0
                shift
                ;;
            --overlay-upgrade)
                MODE="overlay"
                OVERLAY_BACKUP=0
                OVERLAY_UPGRADE=1
                FORCE=1
                shift
                ;;
            --detect-namespace)
                DETECT_NAMESPACE_ONLY=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -* )
                fail "Unknown option: $1"
                ;;
            *)
                if [[ -z "$TARGET_DIR" ]]; then
                    TARGET_DIR="$1"
                    shift
                    break
                else
                    fail "Multiple target directories specified"
                fi
                ;;
        esac
    done

    if [[ $# -gt 0 ]]; then
        if [[ -z "$TARGET_DIR" ]]; then
            TARGET_DIR="$1"
            shift
        else
            fail "Unexpected arguments: $*"
        fi
    fi

    if [[ $# -gt 0 ]]; then
        fail "Unexpected arguments: $*"
    fi

    if [[ -z "$TARGET_DIR" ]]; then
        fail "TARGET_DIRECTORY is required"
    fi

    if [[ $OVERLAY_BACKUP -eq 0 && "$MODE" != "overlay" ]]; then
        fail "--overlay-no-backup is only supported when --mode overlay is set"
    fi

    if [[ -z "$LANGS" ]]; then
        LANGS="$DEFAULT_LANGS"
    fi

    TARGET_DIR="$(absolute_path "$TARGET_DIR")"
}

ensure_source_repo() {
    if [[ ! -f "$SOURCE_REPO/AGENTS.md" || ! -d "$SOURCE_REPO/.agents" ]]; then
        fail "Run this script from within the interruptus repository"
    fi
}

validate_bundle_manifest() {
    local sentinel_path="$1"
    if [[ ! -f "$sentinel_path" ]]; then
        printf '%s\n' "missing"
        return 0
    fi

    local output
    if output="$(python3 - "$sentinel_path" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
try:
    payload = json.loads(path.read_text(encoding="utf-8"))
except Exception as exc:  # noqa: BLE001
    print(f"invalid:unparseable_json:{exc.__class__.__name__}")
    sys.exit(1)

errors = []

if payload.get("bundle_id") != "parallelus.bundle.v1":
    errors.append("bundle_id")

if not isinstance(payload.get("layout_version"), int):
    errors.append("layout_version")

upstream_repo = payload.get("upstream_repo")
if not isinstance(upstream_repo, str) or not upstream_repo.strip():
    errors.append("upstream_repo")

bundle_version = payload.get("bundle_version")
if not isinstance(bundle_version, str) or not bundle_version.strip():
    errors.append("bundle_version")

installed_on = payload.get("installed_on")
if not isinstance(installed_on, str) or not installed_on.strip():
    errors.append("installed_on")

managed_paths = payload.get("managed_paths")
if not isinstance(managed_paths, list) or any(not isinstance(item, str) for item in managed_paths):
    errors.append("managed_paths")
else:
    managed = set(managed_paths)
    if "engine" not in managed or "manuals" not in managed:
        errors.append("managed_paths_required")

if errors:
    print("invalid:" + ",".join(errors))
    sys.exit(1)

print("valid")
PY
 )"; then
        printf '%s\n' "$output"
    else
        printf '%s\n' "$output"
    fi
}

detect_legacy_parallelus_signals() {
    NAMESPACE_STRONG_COUNT=0
    NAMESPACE_CONTEXT_COUNT=0
    NAMESPACE_STRONG_MATCHES=()
    NAMESPACE_CONTEXT_MATCHES=()

    local strong_path
    local strong_paths=(
        ".agents/bin/agents-session-start"
        ".agents/bin/agents-ensure-feature"
        ".agents/hooks/pre-commit"
        ".agents/prompts/agent_roles/senior_architect.md"
    )
    for strong_path in "${strong_paths[@]}"; do
        if [[ -f "$TARGET_DIR/$strong_path" ]]; then
            NAMESPACE_STRONG_MATCHES+=("$strong_path")
            NAMESPACE_STRONG_COUNT=$((NAMESPACE_STRONG_COUNT + 1))
        fi
    done

    if [[ -f "$TARGET_DIR/AGENTS.md" ]] && grep -q "Parallelus Agent Core Guardrails" "$TARGET_DIR/AGENTS.md"; then
        NAMESPACE_CONTEXT_MATCHES+=("AGENTS.md:Parallelus Agent Core Guardrails")
        NAMESPACE_CONTEXT_COUNT=$((NAMESPACE_CONTEXT_COUNT + 1))
    fi

    if [[ -f "$TARGET_DIR/Makefile" ]] && \
       (grep -q "make start_session" "$TARGET_DIR/Makefile" || grep -q "\.agents/bin/" "$TARGET_DIR/Makefile"); then
        NAMESPACE_CONTEXT_MATCHES+=("Makefile:make start_session|.agents/bin/")
        NAMESPACE_CONTEXT_COUNT=$((NAMESPACE_CONTEXT_COUNT + 1))
    fi
}

detect_bundle_namespace() {
    local force_in_place=0
    local force_vendor=0

    NAMESPACE_OVERRIDE_USED=0
    NAMESPACE_PARALLELUS_SENTINEL="$(validate_bundle_manifest "$TARGET_DIR/parallelus/.parallelus-bundle.json")"
    NAMESPACE_VENDOR_SENTINEL="$(validate_bundle_manifest "$TARGET_DIR/vendor/parallelus/.parallelus-bundle.json")"
    detect_legacy_parallelus_signals

    if is_truthy "${PARALLELUS_UPGRADE_FORCE_IN_PLACE:-}"; then
        force_in_place=1
    fi
    if is_truthy "${PARALLELUS_UPGRADE_FORCE_VENDOR:-}"; then
        force_vendor=1
    fi

    if [[ $force_in_place -eq 1 && $force_vendor -eq 1 ]]; then
        fail "PARALLELUS_UPGRADE_FORCE_IN_PLACE and PARALLELUS_UPGRADE_FORCE_VENDOR cannot both be set"
    fi

    if [[ $force_in_place -eq 1 ]]; then
        NAMESPACE_DECISION="parallelus"
        NAMESPACE_REASON="override_force_in_place"
        NAMESPACE_OVERRIDE_USED=1
        return
    fi
    if [[ $force_vendor -eq 1 ]]; then
        NAMESPACE_DECISION="vendor/parallelus"
        NAMESPACE_REASON="override_force_vendor"
        NAMESPACE_OVERRIDE_USED=1
        return
    fi

    if [[ "$NAMESPACE_PARALLELUS_SENTINEL" == "valid" && "$NAMESPACE_VENDOR_SENTINEL" == "valid" ]]; then
        warn "Detected valid sentinels in both parallelus/ and vendor/parallelus; preferring parallelus/"
        NAMESPACE_DECISION="parallelus"
        NAMESPACE_REASON="sentinel_parallelus_preferred_dual"
        return
    fi
    if [[ "$NAMESPACE_PARALLELUS_SENTINEL" == "valid" ]]; then
        NAMESPACE_DECISION="parallelus"
        NAMESPACE_REASON="sentinel_parallelus"
        return
    fi
    if [[ "$NAMESPACE_VENDOR_SENTINEL" == "valid" ]]; then
        NAMESPACE_DECISION="vendor/parallelus"
        NAMESPACE_REASON="sentinel_vendor"
        return
    fi

    if [[ $NAMESPACE_STRONG_COUNT -ge 2 && $NAMESPACE_CONTEXT_COUNT -ge 1 ]]; then
        NAMESPACE_DECISION="parallelus"
        NAMESPACE_REASON="legacy_parallelus"
    else
        NAMESPACE_DECISION="vendor/parallelus"
        NAMESPACE_REASON="ambiguous_or_unrelated"
    fi

    if [[ "$NAMESPACE_DECISION" == "parallelus" && "$NAMESPACE_PARALLELUS_SENTINEL" == invalid:* ]]; then
        if [[ "$NAMESPACE_VENDOR_SENTINEL" == invalid:* ]]; then
            fail "Malformed sentinels found in both namespaces; set exactly one PARALLELUS_UPGRADE_FORCE_* override"
        fi
        warn "parallelus/.parallelus-bundle.json is malformed; refusing in-place overwrite without explicit override"
        NAMESPACE_DECISION="vendor/parallelus"
        NAMESPACE_REASON="parallelus_malformed_fallback_vendor"
    fi

    if [[ "$NAMESPACE_DECISION" == "vendor/parallelus" && "$NAMESPACE_VENDOR_SENTINEL" == invalid:* ]]; then
        if [[ "$NAMESPACE_PARALLELUS_SENTINEL" == invalid:* ]]; then
            fail "Malformed sentinels found in both namespaces; set exactly one PARALLELUS_UPGRADE_FORCE_* override"
        fi
        warn "vendor/parallelus/.parallelus-bundle.json is malformed; refusing vendor overwrite without explicit override"
        NAMESPACE_DECISION="parallelus"
        NAMESPACE_REASON="vendor_malformed_fallback_parallelus"
    fi
}

print_bundle_namespace_detection() {
    echo "NAMESPACE_DECISION=$NAMESPACE_DECISION"
    echo "NAMESPACE_REASON=$NAMESPACE_REASON"
    echo "NAMESPACE_OVERRIDE_USED=$NAMESPACE_OVERRIDE_USED"
    echo "PARALLELUS_SENTINEL_STATUS=$NAMESPACE_PARALLELUS_SENTINEL"
    echo "VENDOR_SENTINEL_STATUS=$NAMESPACE_VENDOR_SENTINEL"
    echo "LEGACY_STRONG_COUNT=$NAMESPACE_STRONG_COUNT"
    echo "LEGACY_CONTEXT_COUNT=$NAMESPACE_CONTEXT_COUNT"
    echo "LEGACY_STRONG_MATCHES=$(join_csv "${NAMESPACE_STRONG_MATCHES[@]}")"
    echo "LEGACY_CONTEXT_MATCHES=$(join_csv "${NAMESPACE_CONTEXT_MATCHES[@]}")"
}

prepare_destination() {
    if [[ "$MODE" == "scaffold" ]]; then
        if [[ -e "$TARGET_DIR" ]]; then
            if [[ ! -d "$TARGET_DIR" ]]; then
                fail "Target path exists and is not a directory"
            fi
            if [[ $FORCE -eq 0 ]]; then
                if find "$TARGET_DIR" -mindepth 1 -maxdepth 1 -print -quit | grep -q '.'; then
                    fail "Target directory is not empty (use --force to scaffold anyway)"
                fi
            fi
        else
            mkdir -p "$TARGET_DIR"
        fi
        mkdir -p "$TARGET_DIR"
        (cd "$TARGET_DIR" && git init >/dev/null && git branch -M "$BASE_BRANCH")
        if [[ -n "$REMOTE_URL" ]]; then
            if (cd "$TARGET_DIR" && git remote get-url origin >/dev/null 2>&1); then
                (cd "$TARGET_DIR" && git remote set-url origin "$REMOTE_URL")
            else
                (cd "$TARGET_DIR" && git remote add origin "$REMOTE_URL")
            fi
        fi
    else
        if [[ ! -d "$TARGET_DIR/.git" ]]; then
            fail "Overlay mode requires TARGET_DIRECTORY to be an existing git repository"
        fi
        if [[ $OVERLAY_UPGRADE -eq 1 ]]; then
            if [[ -n "$(cd "$TARGET_DIR" && git status --porcelain)" ]]; then
                fail "--overlay-upgrade requires a clean working tree in the target repository"
            fi
        fi
        if [[ $FORCE -eq 0 ]]; then
            if [[ -n "$(cd "$TARGET_DIR" && git status --porcelain)" ]]; then
                fail "Overlay target has uncommitted changes (use --force to continue)"
            fi
        fi
    fi
}

diff_exists() {
    local src="$1"
    local dest="$2"
    if [[ ! -e "$dest" ]]; then
        return 1
    fi
    local output
    if [[ -d "$src" ]]; then
        output=$(rsync -rcni --exclude '.git' "$src/" "$dest/" 2>/dev/null || true)
    else
        output=$(rsync -rcni "$src" "$dest" 2>/dev/null || true)
    fi
    [[ -n "$output" ]]
}

warn_overlay_overwrites() {
    if [[ "$MODE" != "overlay" ]]; then
        return
    fi
    local collisions=()
    local path
    for path in AGENTS.md .agents docs/agents docs/reviews Makefile .gitignore; do
        if diff_exists "$SOURCE_REPO/$path" "$TARGET_DIR/$path"; then
            collisions+=("$path")
        fi
    done
    if [[ ${#collisions[@]} -eq 0 ]]; then
        return
    fi
    warn "Overlay will refresh existing paths: ${collisions[*]}"
    if [[ $OVERLAY_BACKUP -eq 1 ]]; then
        warn "Backups will be written with the .bak suffix. Merge prior guidance before deleting them."
    else
        warn "Backups are disabled for this run; ensure you have commits or other recovery points before proceeding."
    fi
    if [[ $FORCE -eq 0 ]]; then
        fail "Re-run with --force after reviewing the warning above"
    fi
}

backup_in_place_file() {
    local path="$1"
    if [[ "$MODE" != "overlay" || $OVERLAY_BACKUP -eq 0 ]]; then
        return
    fi
    if [[ ! -f "$path" ]]; then
        return
    fi
    local backup="${path}.bak"
    if [[ -f "$backup" ]]; then
        return
    fi
    cp "$path" "$backup"
    warn "Backed up $(basename "$path") to $(basename "$backup")"
}

backup_existing_git_hooks() {
    local git_hooks="$TARGET_DIR/.git/hooks"
    if [[ ! -d "$git_hooks" ]]; then
        return
    fi
    local agents_hooks="$TARGET_DIR/.agents/hooks"
    mkdir -p "$agents_hooks"
    local ts
    ts=$(date -u '+%Y%m%d%H%M%S')
    local backed_up=0
    local hook_path hook_name dest source_hook
    for hook_path in "$git_hooks"/*; do
        [[ -f "$hook_path" ]] || continue
        hook_name=$(basename "$hook_path")
        [[ "$hook_name" == *.sample ]] && continue
        [[ "$hook_name" == *.predeploy.*.bak ]] && continue
        source_hook="$SOURCE_REPO/.agents/hooks/$hook_name"
        if [[ -f "$source_hook" ]] && cmp -s "$hook_path" "$source_hook"; then
            continue
        fi
        dest="$agents_hooks/${hook_name}.predeploy.$ts.bak"
        cp "$hook_path" "$dest"
        backed_up=1
    done
    if [[ $backed_up -eq 1 ]]; then
        warn "Preserved existing .git/hooks scripts under .agents/hooks/*.predeploy.*.bak"
    fi
}

rsync_copy() {
    local src="$1"
    local dest="$2"
    shift 2 || true
    local extra=()
    if [[ $# -gt 0 ]]; then
        extra=("$@")
    fi
    local opts=(-a --no-perms --no-group --no-owner)
    if [[ "$MODE" == "overlay" && $OVERLAY_BACKUP -eq 1 ]]; then
        opts+=(--backup --suffix=.bak)
    fi

    if [[ -d "$src" ]]; then
        mkdir -p "$dest"
        if [[ ${#extra[@]} -gt 0 ]]; then
            rsync "${opts[@]}" --exclude '.git' "${extra[@]}" "$src" "$dest"
        else
            rsync "${opts[@]}" --exclude '.git' "$src" "$dest"
        fi
    else
        mkdir -p "$(dirname "$dest")"
        if [[ ${#extra[@]} -gt 0 ]]; then
            rsync "${opts[@]}" "${extra[@]}" "$src" "$dest"
        else
            rsync "${opts[@]}" "$src" "$dest"
        fi
    fi
}

ensure_dir_with_readme() {
    local dir="$1"
    local title="$2"
    local example="$3"
    local noun="$4"
    mkdir -p "$dir"
    local readme="$dir/README.md"
    if [[ ! -f "$readme" ]]; then
        cat > "$readme" <<EOF
# $title

This directory stores $noun files created by the Parallelus agent process (for example, "$example").
Files are generated by `make bootstrap` and cleaned up during `make archive` / `make merge`.
EOF
    fi
}

ensure_canonical_docs() {
    local plan="$TARGET_DIR/docs/PLAN.md"
    local progress="$TARGET_DIR/docs/PROGRESS.md"
    if [[ ! -f "$plan" ]]; then
        mkdir -p "$(dirname "$plan")"
        cat > "$plan" <<'EOF'
# Project Plan

## Next Focus Areas
- TODO: capture long-term priorities and backlog items here.
EOF
    fi
    if [[ ! -f "$progress" ]]; then
        mkdir -p "$(dirname "$progress")"
        cat > "$progress" <<'EOF'
# Project Progress

## YYYY-MM-DD

### HH:MM:SS UTC — feature/<slug>

**Summary**
- TODO: record branch summary.

**Artifacts**
- TODO: list touched files.

**Next Actions**
- TODO: follow-up items.
EOF
    fi
}

ensure_self_improvement_scaffold() {
    local base="$TARGET_DIR/docs/self-improvement"
    mkdir -p "$base/markers" "$base/reports" "$base/failures"
    local readme="$base/README.md"
    if [[ ! -f "$readme" ]]; then
        cat > "$readme" <<'EOF'
# Self-Improvement Retrospectives

This directory stores two types of artifacts:

1. **Turn markers** (`markers/<branch>.json`) created automatically by
   `.agents/bin/retro-marker` when the main agent runs `make turn_end`.
   Markers record the timestamp, plan/progress snapshot, session console offset,
   and current commit so retrospective auditors know exactly where to resume
   analysis.
2. **Retrospective reports** (`reports/<branch>--<marker-timestamp>.json`)
   written by the Retrospective Auditor subagent. Each report must follow the
   schema described in `.agents/prompts/agent_roles/continuous_improvement_auditor.md` and is
   committed by the main agent after review.

Merge guardrails require that the latest marker for a branch has a corresponding
report committed before `make merge slug=<slug>` will succeed.
EOF
    fi
    for keep in "$base/markers/.gitkeep" "$base/reports/.gitkeep" "$base/failures/.gitkeep"; do
        if [[ ! -f "$keep" ]]; then
            printf '%s\n' "" > "$keep"
        fi
    done
}

copy_base_assets() {
    info "Copying agent process assets"
    backup_existing_git_hooks
    rsync_copy "$SOURCE_REPO/AGENTS.md" "$TARGET_DIR/AGENTS.md"
    rsync_copy "$SOURCE_REPO/.agents/" "$TARGET_DIR/.agents/"

    local project_preserved=0
    if [[ "$MODE" == "overlay" && -d "$TARGET_DIR/docs/agents/project" ]]; then
        project_preserved=1
        rsync_copy "$SOURCE_REPO/docs/agents/" "$TARGET_DIR/docs/agents/" --exclude 'project/'
    else
        rsync_copy "$SOURCE_REPO/docs/agents/" "$TARGET_DIR/docs/agents/"
    fi
    if [[ "$MODE" == "overlay" ]]; then
        rsync_copy "$SOURCE_REPO/docs/reviews/README.md" "$TARGET_DIR/docs/reviews/README.md"
    else
        rsync_copy "$SOURCE_REPO/docs/reviews/" "$TARGET_DIR/docs/reviews/"
    fi
    mkdir -p "$TARGET_DIR/sessions"
    ensure_dir_with_readme "$TARGET_DIR/docs/plans" "Branch Plans" "feature/my-feature.md" "plan"
    ensure_dir_with_readme "$TARGET_DIR/docs/progress" "Branch Progress" "feature/my-feature.md" "progress"
    ensure_canonical_docs
    ensure_self_improvement_scaffold

    if [[ $project_preserved -eq 1 ]]; then
        warn "Preserved existing docs/agents/project/ content (merge templates manually if desired)."
    fi
}

install_hooks_into_repo() {
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        return
    fi
    info "Installing managed git hooks"
    (cd "$TARGET_DIR" && .agents/bin/install-hooks --quiet || true)
}

annotate_agents_overlay() {
    if [[ "$MODE" != "overlay" ]]; then
        return
    fi
    if [[ $OVERLAY_BACKUP -eq 0 ]]; then
        return
    fi
    local agents_file="$TARGET_DIR/AGENTS.md"
    if [[ ! -f "$agents_file" ]]; then
        return
    fi
    python3 - "$agents_file" <<'PY'
import sys
from pathlib import Path
from datetime import datetime, timezone

agents_path = Path(sys.argv[1])
notice = (
    f"> **Overlay Notice ({datetime.now(timezone.utc).date()})**\n"
    "> This repository now contains a refreshed AGENTS.md. Backups (.bak) were created for every overwritten file (for example AGENTS.md.bak). "
    "Merge any project-specific instructions from those backups into the new guardrails, record the outcome in the branch plan, then remove this notice.\n\n"
)

text = agents_path.read_text()
if notice in text:
    sys.exit(0)
agents_path.write_text(f"{notice}{text}")
PY
}

update_agentrc() {
    local file="$TARGET_DIR/.agents/agentrc"
    if [[ ! -f "$file" ]]; then
        warn ".agents/agentrc not found after copy"
        return
    fi
    python3 - <<'PY' "$file" "$PROJECT_NAME" "$BASE_BRANCH" "$LANGS"
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
project = sys.argv[2]
base = sys.argv[3]
langs = sys.argv[4]
text = path.read_text()

def replace(line, value, data):
    pattern = rf'^{line}=".*"$'
    repl = f'{line}="{value}"'
    if re.search(pattern, data, flags=re.MULTILINE):
        return re.sub(pattern, repl, data, flags=re.MULTILINE)
    return data + f"\n{repl}\n"

text = replace('PROJECT_NAME', project, text)
text = replace('DEFAULT_BASE', base, text)
text = replace('LANG_ADAPTERS', langs, text)
path.write_text(text)
PY
}

generate_makefile_snippet() {
    local adapter_block=""
    local lang
    for lang in $LANGS; do
        case "$lang" in
            python)
                adapter_block+=$'ifneq (,$(findstring python,$(LANG_ADAPTERS)))\n'
                adapter_block+=$'include $(AGENTS_DIR)/make/python.mk\n'
                adapter_block+=$'endif\n\n'
                ;;
            swift)
                adapter_block+=$'ifneq (,$(findstring swift,$(LANG_ADAPTERS)))\n'
                adapter_block+=$'include $(AGENTS_DIR)/make/swift.mk\n'
                adapter_block+=$'endif\n\n'
                ;;
        esac
    done

    printf '%s\n' '# >>> agent-process integration >>>'
    printf '%s\n' 'ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))'
    printf '%s\n' 'AGENTS_DIR ?= $(ROOT)/.agents'
    printf 'LANG_ADAPTERS ?= %s\n\n' "$LANGS"
    printf '%s\n' 'include $(AGENTS_DIR)/make/agents.mk'
    printf '%s' "$adapter_block"
    printf '%s\n' '# <<< agent-process integration <<<'
}

ensure_makefile() {
    local makefile="$TARGET_DIR/Makefile"
    local snippet="$(generate_makefile_snippet)"
    local tmp="$(mktemp)"
    printf '%s\n' "$snippet" > "$tmp"
    if [[ ! -f "$makefile" ]]; then
        cat > "$makefile" <<EOF
# Makefile for $PROJECT_NAME

$snippet

.PHONY: help setup

help:
	@echo "$PROJECT_NAME - Agent Process"
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
EOF
        rm "$tmp"
        return
    fi

    backup_in_place_file "$makefile"
    if grep -q '# >>> agent-process integration >>>' "$makefile"; then
        python3 - <<'PY' "$makefile" "$tmp"
import sys
from pathlib import Path

makefile = Path(sys.argv[1])
snippet_path = Path(sys.argv[2])
snippet = snippet_path.read_text()
start = '# >>> agent-process integration >>>'
end = '# <<< agent-process integration <<<'
text = makefile.read_text()
if start in text and end in text:
    before = text.split(start, 1)[0]
    after = text.split(end, 1)[1]
    if after.startswith('\n'):
        after = after[1:]
    updated = before + snippet + '\n' + after
else:
    updated = text.rstrip() + '\n\n' + snippet + '\n'
makefile.write_text(updated)
PY
    else
        printf '\n%s\n' "$snippet" >> "$makefile"
    fi
    rm "$tmp"
}

ensure_readme() {
    local readme="$TARGET_DIR/README.md"
    if [[ -f "$readme" ]]; then
        return
    fi
    cat > "$readme" <<EOF
# $PROJECT_NAME

This repository is configured with the Parallelus Agent Process.

## Next Steps

1. Read `AGENTS.md` and the documents under `docs/agents/`.
2. Run `make read_bootstrap` to verify repository detection.
3. Use `make bootstrap slug=my-feature` to create your first branch.
4. Update the `setup` target in the `Makefile` for project tooling.

## Language Overlays

Adapters enabled by this deployment: $LANGS.
Update `.agents/agentrc` and the Makefile snippet if you add or remove adapters.

## Documentation

- [AGENTS.md](AGENTS.md)
- [docs/agents/](docs/agents/)
EOF
}

ensure_gitignore() {
    local file="$TARGET_DIR/.gitignore"
    local entries=(
        ".venv/"
        "env/"
        "venv/"
        "__pycache__/"
        "*.pyc"
        ".parallelus/"
        "sessions/"
        "out/"
        "*.log"
        ".DS_Store"
    )

    backup_in_place_file "$file"
    if [[ ! -f "$file" ]]; then
        {
            for entry in "${entries[@]}"; do
                printf '%s\n' "$entry"
            done
        } > "$file"
        return
    fi

    for entry in "${entries[@]}"; do
        if ! grep -Fxq "$entry" "$file"; then
            printf '%s\n' "$entry" >> "$file"
        fi
    done
}

copy_helper_scripts() {
    local makefile="$TARGET_DIR/Makefile"
    if [[ ! -f "$SOURCE_REPO/scripts/remember_later.py" && ! -f "$SOURCE_REPO/scripts/capsule_prompt.py" ]]; then
        return
    fi
    if [[ "$MODE" == "scaffold" ]]; then
        rsync_copy "$SOURCE_REPO/scripts/" "$TARGET_DIR/scripts/"
        return
    fi
    if [[ ! -f "$makefile" ]]; then
        return
    fi
    if grep -q -E 'remember_later|capsule_prompt' "$makefile"; then
        rsync_copy "$SOURCE_REPO/scripts/" "$TARGET_DIR/scripts/" --ignore-existing
    fi
}

apply_python_overlay() {
    local pkg="$TARGET_DIR/pyproject.toml"
    if [[ ! -f "$pkg" ]]; then
        cat > "$pkg" <<EOF
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "$PROJECT_NAME"
version = "0.1.0"
description = "Project configured with the Parallelus Agent Process"
requires-python = ">=3.11"
EOF
    fi

    local req="$TARGET_DIR/requirements.txt"
    if [[ ! -f "$req" ]]; then
        cat > "$req" <<'EOF'
# List project dependencies here (pip-style, one per line).
EOF
    fi

    mkdir -p "$TARGET_DIR/src"
    if [[ ! -f "$TARGET_DIR/src/__init__.py" ]]; then
        cat > "$TARGET_DIR/src/__init__.py" <<'EOF'
# Primary package module.
EOF
    fi

    mkdir -p "$TARGET_DIR/tests"
    if [[ ! -f "$TARGET_DIR/tests/test_basic.py" ]]; then
        cat > "$TARGET_DIR/tests/test_basic.py" <<'EOF'
"""Basic smoke test."""

def test_basic():
    assert True
EOF
    fi
}

apply_swift_overlay() {
    local pkg="$TARGET_DIR/Package.swift"
    if [[ ! -f "$pkg" ]]; then
        cat > "$pkg" <<EOF
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "$PROJECT_NAME",
    products: [
        .library(name: "$PROJECT_NAME", targets: ["$PROJECT_NAME"])
    ],
    targets: [
        .target(name: "$PROJECT_NAME"),
        .testTarget(name: "${PROJECT_NAME}Tests", dependencies: ["$PROJECT_NAME"])
    ]
)
EOF
    fi

    mkdir -p "$TARGET_DIR/Sources/$PROJECT_NAME"
    if [[ ! -f "$TARGET_DIR/Sources/$PROJECT_NAME/$PROJECT_NAME.swift" ]]; then
        cat > "$TARGET_DIR/Sources/$PROJECT_NAME/$PROJECT_NAME.swift" <<EOF
public struct $PROJECT_NAME {
    public init() {}
    public func hello() -> String { "Hello, $PROJECT_NAME!" }
}
EOF
    fi

    mkdir -p "$TARGET_DIR/Tests/${PROJECT_NAME}Tests"
    if [[ ! -f "$TARGET_DIR/Tests/${PROJECT_NAME}Tests/${PROJECT_NAME}Tests.swift" ]]; then
        cat > "$TARGET_DIR/Tests/${PROJECT_NAME}Tests/${PROJECT_NAME}Tests.swift" <<EOF
import XCTest
@testable import $PROJECT_NAME

final class ${PROJECT_NAME}Tests: XCTestCase {
    func testHello() {
        XCTAssertEqual($PROJECT_NAME().hello(), "Hello, $PROJECT_NAME!")
    }
}
EOF
    fi

    if [[ ! -f "$TARGET_DIR/.swiftlint.yml" ]]; then
        cat > "$TARGET_DIR/.swiftlint.yml" <<'EOF'
opt_in_rules:
  - unused_import
EOF
    fi

    if [[ ! -f "$TARGET_DIR/.swiftformat" ]]; then
        cat > "$TARGET_DIR/.swiftformat" <<'EOF'
--indent 4
EOF
    fi
}

apply_language_overlays() {
    local lang
    for lang in $LANGS; do
        case "$lang" in
            python)
                apply_python_overlay
                ;;
            swift)
                apply_swift_overlay
                ;;
        esac
    done
}

run_verification() {
    if [[ $VERIFY -eq 0 ]]; then
        return
    fi
    if [[ "$MODE" != "scaffold" ]]; then
        warn "--verify is only supported in scaffold mode"
        return
    fi
    info "Running bootstrap verification"
    local slug="scaffold-smoke"
    pushd "$TARGET_DIR" >/dev/null
    local before_sessions
    before_sessions=$(ls sessions 2>/dev/null || true)
    make read_bootstrap >/dev/null
    make bootstrap slug="$slug" >/dev/null
    SESSION_PROMPT="Smoke test" make start_session >/dev/null
    make turn_end m="initial checkpoint" >/dev/null
    make agents-smoke >/dev/null
    make archive b="feature/$slug" >/dev/null
    git branch -D "archive/feature/$slug" >/dev/null 2>&1 || true
    rm -f "docs/plans/feature-$slug.md" "docs/progress/feature-$slug.md"
    local after_sessions
    after_sessions=$(ls sessions 2>/dev/null || true)
    for session in $after_sessions; do
        case " $before_sessions " in
            *" $session "*) ;;
            *) rm -rf "sessions/$session" ;;
        esac
    done
    popd >/dev/null
}

create_initial_commit() {
    if [[ "$MODE" != "scaffold" ]]; then
        return
    fi
    pushd "$TARGET_DIR" >/dev/null
    if [[ -z "$(git status --porcelain)" ]]; then
        info "Nothing to commit"
        popd >/dev/null
        return
    fi
    git add . >/dev/null
    git commit -m "chore: bootstrap agent process for $PROJECT_NAME" >/dev/null
    popd >/dev/null
    info "Initial commit created"
}

main() {
    parse_args "$@"
    ensure_source_repo
    if [[ $DETECT_NAMESPACE_ONLY -eq 1 ]]; then
        if [[ ! -d "$TARGET_DIR" ]]; then
            fail "--detect-namespace requires TARGET_DIRECTORY to exist"
        fi
        detect_bundle_namespace
        print_bundle_namespace_detection
        return
    fi
    info "Deploying agent process"
    echo " Mode: $MODE"
    echo " Target: $TARGET_DIR"
    echo " Languages: $LANGS"
    if [[ $OVERLAY_UPGRADE -eq 1 ]]; then
        echo " Overlay upgrade: true (backups disabled)"
    fi
    prepare_destination
    if [[ "$MODE" == "overlay" ]]; then
        detect_bundle_namespace
        info "Namespace detection:"
        print_bundle_namespace_detection
    fi
    warn_overlay_overwrites
    copy_base_assets
    install_hooks_into_repo
    annotate_agents_overlay
    update_agentrc
    ensure_makefile
    ensure_readme
    ensure_gitignore
    copy_helper_scripts
    apply_language_overlays
    run_verification
    create_initial_commit
    info "Deployment complete"
    if [[ -n "$REMOTE_URL" ]]; then
        echo "Next: git push -u origin $BASE_BRANCH"
    fi
}

main "$@"
