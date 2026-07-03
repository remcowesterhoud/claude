#!/usr/bin/env bash
# Statusline wrapper: runs claude-hud, then appends GitHub PR/CI status line.

set -uo pipefail

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // ""' 2>/dev/null)
if [ -z "$cwd" ] || [ ! -d "$cwd" ]; then cwd="$PWD"; fi

cols=$(stty size </dev/tty 2>/dev/null | awk '{print $2}')
export COLUMNS=$(( ${cols:-120} > 4 ? ${cols:-120} - 4 : 1 ))

plugin_dir=$(ls -d "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/claude-hud/*/ 2>/dev/null \
  | awk -F/ '{ print $(NF-1) "\t" $(0) }' \
  | grep -E '^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]' \
  | sort -t. -k1,1n -k2,2n -k3,3n -k4,4n \
  | tail -1 \
  | cut -f2-)

printf '%s' "$input" | /opt/homebrew/bin/node "${plugin_dir}dist/index.js"

gh_line=$("$HOME/.claude/scripts/gh-cli-status/render.sh" "$cwd" 2>/dev/null || true)
if [ -n "$gh_line" ]; then
  printf '\n%s' "$gh_line"
fi
