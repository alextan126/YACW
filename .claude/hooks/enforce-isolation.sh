#!/usr/bin/env bash
# PreToolUse hook for Claude Code. Enforces the code/test isolation wall
# and per-agent write zones defined in CLAUDE.md.
#
# Reads PreToolUse JSON from stdin. The fields agent_id and agent_type
# are present when a tool call originates from a subagent. Main-thread
# tool calls have no agent_type and are unrestricted by this hook.
#
# On a violation, emits a hookSpecificOutput JSON denying the call and
# exits 0. On allow, exits 0 silently.

set -uo pipefail

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "enforce-isolation: jq not installed; skipping isolation check" >&2
  exit 0
fi

agent_type=$(printf '%s' "$INPUT" | jq -r '.agent_type // ""')
tool_name=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

[ -z "$agent_type" ] && exit 0

case "$tool_name" in
  Read|Edit|Write|MultiEdit)
    raw=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
    op="read"
    case "$tool_name" in Edit|Write|MultiEdit) op="write" ;; esac
    ;;
  Glob|Grep)
    raw=$(printf '%s' "$INPUT" | jq -r '.tool_input.path // ""')
    op="read"
    ;;
  *)
    exit 0
    ;;
esac

project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
abs="$raw"
[[ -n "$abs" && "$abs" != /* ]] && abs="$project_dir/$abs"

if [ -z "$abs" ]; then
  rel=""
elif [[ "$abs" == "$project_dir" ]]; then
  rel=""
elif [[ "$abs" == "$project_dir"/* ]]; then
  rel="${abs#"$project_dir"/}"
else
  rel="$abs"
fi

is_c_test_path() {
  local p="$1"
  [[ "$p" == c-source/tests/* || "$p" == c-source/test/* ]] && return 0
  [[ "$p" == c-source/* ]] || return 1
  local b="${p##*/}"
  case "$b" in
    test_*.c|test_*.h|*_test.c|*_test.h|check_*.c) return 0 ;;
  esac
  return 1
}

matches_prefix() {
  local p="$1" pat="$2"
  if [[ "$pat" == *"/**" ]]; then
    local prefix="${pat%/**}"
    [[ "$p" == "$prefix" || "$p" == "$prefix"/* ]]
  else
    [[ "$p" == "$pat" ]]
  fi
}

deny() {
  local reason="$1"
  jq -nc \
    --arg name "PreToolUse" \
    --arg dec "deny" \
    --arg why "$reason" \
    '{hookSpecificOutput:{hookEventName:$name, permissionDecision:$dec, permissionDecisionReason:$why}}'
  exit 0
}

allowed=0

case "$agent_type" in
  c-code-reader)
    if [ "$op" = "read" ]; then
      if matches_prefix "$rel" "c-source/**"; then
        if is_c_test_path "$rel"; then
          deny "c-code-reader may not read C test files ('$rel') — see CLAUDE.md §2 (code/test wall)"
        fi
        allowed=1
      fi
    else
      matches_prefix "$rel" "specs/code/**" && allowed=1
    fi
    ;;
  c-test-reader)
    if [ "$op" = "read" ]; then
      if matches_prefix "$rel" "c-source/**"; then
        if is_c_test_path "$rel"; then
          allowed=1
        else
          deny "c-test-reader may only read C test files; '$rel' is not a test path — see CLAUDE.md §2"
        fi
      fi
    else
      matches_prefix "$rel" "specs/tests/**" && allowed=1
    fi
    ;;
  code-planner)
    if [ "$op" = "read" ]; then
      matches_prefix "$rel" "specs/code/**" && allowed=1
      [ "$rel" = "plans/code-plan.md" ] && allowed=1
    else
      [ "$rel" = "plans/code-plan.md" ] && allowed=1
    fi
    ;;
  test-planner)
    if [ "$op" = "read" ]; then
      matches_prefix "$rel" "specs/tests/**" && allowed=1
      [ "$rel" = "plans/test-plan.md" ] && allowed=1
    else
      [ "$rel" = "plans/test-plan.md" ] && allowed=1
    fi
    ;;
  translator)
    if [ "$op" = "read" ]; then
      matches_prefix "$rel" "specs/code/**" && allowed=1
      matches_prefix "$rel" "rust-output/src/**" && allowed=1
      matches_prefix "$rel" "plans/api/**" && allowed=1
      [ "$rel" = "plans/code-plan.md" ] && allowed=1
      [ "$rel" = "rust-output/Cargo.toml" ] && allowed=1
    else
      matches_prefix "$rel" "rust-output/src/**" && allowed=1
      matches_prefix "$rel" "plans/api/**" && allowed=1
      [ "$rel" = "rust-output/Cargo.toml" ] && allowed=1
    fi
    ;;
  test-translator)
    if [ "$op" = "read" ]; then
      matches_prefix "$rel" "specs/tests/**" && allowed=1
      matches_prefix "$rel" "plans/api/**" && allowed=1
      matches_prefix "$rel" "rust-output/tests/**" && allowed=1
      [ "$rel" = "plans/test-plan.md" ] && allowed=1
      [ "$rel" = "rust-output/Cargo.toml" ] && allowed=1
    else
      matches_prefix "$rel" "rust-output/tests/**" && allowed=1
    fi
    ;;
  dev-helper)
    if [ "$op" = "read" ]; then
      allowed=1
    else
      matches_prefix "$rel" "prompt-log/**" && allowed=1
    fi
    ;;
  *)
    echo "enforce-isolation: unknown agent_type '$agent_type'; allowing" >&2
    exit 0
    ;;
esac

if [ "$allowed" -eq 1 ]; then
  exit 0
fi

deny "$agent_type may not $op '$rel' — see CLAUDE.md §2 (isolation rules)"
