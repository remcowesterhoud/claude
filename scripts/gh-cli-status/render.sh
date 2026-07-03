#!/usr/bin/env bash
# Reads cached PR status and renders a one-line statusline addition.
# Triggers a background refresh if cache is stale (TTL from config.json).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="${1:-$PWD}"

config_file="$SCRIPT_DIR/config.json"
ttl=60
if [ -f "$config_file" ]; then
  ttl_from_config=$(jq -r '.refreshIntervalSeconds // 60' "$config_file" 2>/dev/null)
  case "$ttl_from_config" in
    ''|*[!0-9]*) ;;
    *) ttl="$ttl_from_config" ;;
  esac
fi

remote_url=$(git -C "$REPO_DIR" remote get-url origin 2>/dev/null || true)
case "$remote_url" in
  *github.com*) ;;
  *) exit 0 ;;
esac

branch=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [ -z "$branch" ] || [ "$branch" = "HEAD" ]; then
  exit 0
fi

key=$(printf '%s|%s' "$remote_url" "$branch" | shasum -a 1 | cut -c1-12)
cache_file="/tmp/claude-gh-status-${key}.json"

now=$(date +%s)
fresh=0
if [ -f "$cache_file" ]; then
  fetched_at=$(jq -r '.fetched_at // 0' "$cache_file" 2>/dev/null || echo 0)
  age=$(( now - fetched_at ))
  if [ "$age" -lt "$ttl" ]; then fresh=1; fi
fi

if [ "$fresh" = "0" ]; then
  nohup "$SCRIPT_DIR/refresh.sh" "$REPO_DIR" >/dev/null 2>&1 &
  disown 2>/dev/null || true
fi

if [ ! -f "$cache_file" ]; then exit 0; fi

ESC=$'\033'

jq -r --arg ESC "$ESC" '
  def col(code; text): "\($ESC)[\(code)m\(text)\($ESC)[0m";

  if (.pr // null) == null then ""
  else
    .pr as $pr
    | ($pr.number | tostring) as $num
    | (
        if   $pr.state   == "MERGED"  then {label:"merged",  color:"35"}
        elif $pr.state   == "CLOSED"  then {label:"closed",  color:"31"}
        elif ($pr.isDraft // false)   then {label:"draft",   color:"33"}
        elif ($pr.mergeQueueEntry // null) != null then {label:"queued", color:"36"}
        elif ($pr.mergeStateStatus // "") == "BLOCKED" then {label:"open (blocked)", color:"33"}
        else                               {label:"open",    color:"32"}
        end
      ) as $st
    | ($pr.checks // {}) as $c
    | (
        [
          ($c.pass     // 0 | if . > 0 then col("32"; "✓\(.)") else empty end),
          ($c.fail     // 0 | if . > 0 then col("31"; "✗\(.)") else empty end),
          ($c.pending  // 0 | if . > 0 then col("33"; "◐\(.)") else empty end),
          ($c.cancel   // 0 | if . > 0 then col("90"; "⊘\(.)") else empty end),
          ($c.skipping // 0 | if . > 0 then col("90"; "·\(.)") else empty end)
        ] | join(" ")
      ) as $checks
    | (if $checks == "" then "" else " " + $checks end) as $ciSuffix
    | "\(col("2"; "PR")) \(col("1"; "#\($num)")) \(col($st.color; $st.label))\($ciSuffix)"
  end
' "$cache_file"
