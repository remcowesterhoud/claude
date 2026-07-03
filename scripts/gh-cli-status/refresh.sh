#!/usr/bin/env bash
# Fetches PR + CI status for the current branch and writes a JSON cache file.
# Idempotent and concurrency-safe via mkdir lock.

set -uo pipefail

REPO_DIR="${1:-$PWD}"
cd "$REPO_DIR" 2>/dev/null || exit 0

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
lock_dir="/tmp/claude-gh-status-${key}.lock"

if ! mkdir "$lock_dir" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$lock_dir" 2>/dev/null' EXIT

pr_json=$(gh pr view --json number,state,isDraft,url,mergeStateStatus 2>/dev/null || echo "")

if [ -z "$pr_json" ] || [ "$pr_json" = "null" ]; then
  printf '{"fetched_at":%d,"pr":null}\n' "$(date +%s)" > "$cache_file"
  exit 0
fi

pr_url=$(printf '%s' "$pr_json" | jq -r '.url // ""')
pr_num=$(printf '%s' "$pr_json" | jq -r '.number // empty')
owner=$(printf '%s' "$pr_url" | awk -F/ 'NF>=5 {print $4}')
repo=$(printf '%s' "$pr_url" | awk -F/ 'NF>=5 {print $5}')

mqe_json="null"
if [ -n "$owner" ] && [ -n "$repo" ] && [ -n "$pr_num" ]; then
  mqe_json=$(gh api graphql \
    -f query='query($owner:String!, $repo:String!, $num:Int!) { repository(owner:$owner, name:$repo) { pullRequest(number:$num) { mergeQueueEntry { state position } } } }' \
    -F owner="$owner" -F repo="$repo" -F num="$pr_num" 2>/dev/null \
    | jq -c '.data.repository.pullRequest.mergeQueueEntry // null' 2>/dev/null || echo "null")
fi

checks_json=$(gh pr checks --json bucket 2>/dev/null || echo "[]")
checks_agg=$(printf '%s' "$checks_json" | jq -c 'group_by(.bucket) | map({key: .[0].bucket, value: length}) | from_entries' 2>/dev/null || echo "{}")

jq -n \
  --argjson pr "$pr_json" \
  --argjson mqe "$mqe_json" \
  --argjson checks "$checks_agg" \
  --arg fetched_at "$(date +%s)" \
  '{fetched_at: ($fetched_at|tonumber), pr: ($pr + {mergeQueueEntry: $mqe, checks: $checks})}' \
  > "$cache_file"
