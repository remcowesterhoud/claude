# Operating Guardrails

Cross-cutting defaults for every session (inherited by subagents via CLAUDE.md).

**Context frugality:**
- For files over ~300 lines, use `Read` with `limit`/`offset` to read only the relevant section. The Read tool is NOT filtered by RTK — every returned line costs tokens.
- To find which file contains a symbol, use `grep -rl pattern dir` (filenames only) before content grep or Read.

**Completeness on paginated APIs:**
- For any GitHub/Slack/list API call, paginate fully (`gh api --paginate`, or loop until no next cursor). Before reporting "all green" / "no failures" / "all comments addressed", confirm the retrieved count matches `total_count`. Never claim completeness you haven't verified.

**Secrets:**
- Never read, print, or pipe secret values (private keys, tokens, `.env`/credentials) — tool output is exposed. Hand me a command to run myself instead. Public halves and secret *names* are fine.

**Commits:**
- Choose amend vs. new commit by semantic *intent*, not file overlap: amend when it refines the same intent (typo, missed edge case, fix to the same bug); new commit when it changes what behavior is wanted, even in the same files.

**Writing:**
- Before drafting any PR description, PR review comment, or standup PR summary, read `~/.claude/user_pr_writing_style.md`.
