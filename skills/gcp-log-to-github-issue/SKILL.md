---
name: gcp-log-to-github-issue
description: Use when reviewing GCP Stackdriver log reports during the daily medic shift and need to file a GitHub bug report in camunda/camunda from log evidence
---

# GCP Log → GitHub Issue

## Overview

During the daily medic shift, you receive Stackdriver JSON log payloads from GCP. This skill
guides you through: scrubbing sensitive data, extracting the bug signal, drafting the issue for
user review, and creating it via `gh` CLI only after explicit approval.

**Non-negotiable constraint:** Never include private or customer-identifying data in the issue.
When in doubt, redact.

---

## Step 1 — Redact All Sensitive Data

Before extracting anything, apply these substitutions to all log fields you will use:

| Data type | Replace with |
|-----------|-------------|
| Tenant / org / customer IDs | `[REDACTED-TENANT]` |
| User emails, names, usernames | `[REDACTED-USER]` |
| API tokens, secrets, passwords, keys | `[REDACTED-SECRET]` |
| IP addresses | `[REDACTED-IP]` |
| Process / element instance IDs | `[REDACTED-INSTANCE-ID]` |
| Cluster / node / deployment IDs | `[REDACTED-CLUSTER]` |
| Customer-identifying URLs or hostnames | `[REDACTED-HOST]` |
| Database connection strings | `[REDACTED-CONN]` |
| Any UUID that could identify a customer resource | `[REDACTED-ID]` |

**Scrub from:** `jsonPayload`, `resource.labels`, `httpRequest`, `labels`, exception messages, and
stack trace `message` fields that embed IDs inline.

**Keep (not sensitive):** Java class names, method names, line numbers, thread names, partition
numbers (when not tenant-identifying), Zeebe component names, log severity, timestamps (date only,
strip if request-correlated).

---

## Step 2 — Extract the Bug Signal

From the sanitized log, identify:

- **What failed**: exception type + message (scrubbed)
- **Where**: service/component, class, method. **From 8.9.0+, the `camunda-gateway` container
  hosts multiple modules — gateway, Tasklist, and Operate.** Do not assume `component/zeebe`
  just because the container is `camunda-gateway`. Use the logger name / Java package to identify
  the actual module:
  - `io.camunda.operate.*` → `component/operate`
  - `io.camunda.tasklist.*` → `component/tasklist`
  - `io.camunda.zeebe.*` or `io.camunda.gateway.*` → `component/zeebe`
  - `io.camunda.authentication.*` → `component/identity` (search/service exceptions bubbling up
    through auth are an identity concern — they should be wrapped in auth-domain exceptions)
  - `io.camunda.service.*` alone → ask the user (cross-cutting)
- **Stack trace**: Java stack, scrubbed of any embedded IDs
- **Context clues**: partition, log level, thread name (non-identifying parts only)
- **Zeebe/component version**: from `labels` or `resource.labels` if present
- **SaaS vs SM**: Medic shift logs always come from GCP, so the observed incident is always SaaS.
  But the issue field describes which *deployments are affected by the bug*, not just where it was
  observed. Use this logic:
  - **SaaS only** — bug is caused by SaaS-specific infrastructure (GKE config, GCP services,
    SaaS-specific env vars or secrets)
  - **Both** — bug is in application code (exception, logic error, missing error handling) with
    no platform-specific dependency; SM users could hit the same code path
  - **SM only** — not applicable in medic shift context
  - When unsure, default to **Both** and note it for the user to confirm during review

---

## Step 3 — Search for Existing Issues

Before drafting, check if a similar issue already exists using key terms from the sanitized bug
signal (exception class, method name, error message keywords — never use redacted customer data as
search terms):

```bash
# Search by exception type or error keyword
gh search issues --repo camunda/camunda --state open "ExceptionClassName methodName"

# Broaden if no results
gh search issues --repo camunda/camunda "ExceptionClassName" --label "kind/bug"

# Also check closed issues (may have been fixed or won't-fixed)
gh search issues --repo camunda/camunda --state closed "ExceptionClassName" --limit 5
```

**If a matching issue is found:**
- Report it to the user with URL and title.
- Ask whether to: (a) add a comment to the existing issue, (b) create a new one anyway, or (c) drop it.
- Do not proceed to draft until the user decides.

**If no match:** continue to Step 4.

---

## Step 4 — Draft the Issue

Use this exact template:

```
## Description
[One sentence: what is broken and in which component]

## Current Behavior
[What the logs show: the error, exception, or unexpected state.
Include the sanitized log snippet as a fenced code block.]

```
[SANITIZED LOG SNIPPET]
```

## Expected Behavior
[What should have happened instead — infer from the failure type if not explicit in logs]

## Environment

- SaaS & SM: [SaaS / Both — see Step 2 guidance]
- Version: [from logs or leave as placeholder]
- Component Version: 8.8.21
```

**Issue title format:** Just a descriptive sentence — no component prefix, no brackets, no
conventional commit prefix. Example: `Broker throws NullPointerException on timer expiry with corrupted state`

---

## Step 5 — Present for Review

Output the full draft (title + body) and **stop**. Do not create the issue yet.

Say: *"Here is the draft issue — please review for accuracy and any remaining sensitive data before
I create it."*

Wait for explicit approval ("looks good", "create it", "go ahead", etc.).

---

## Step 6 — Create with gh CLI

After approval, run:

```bash
gh issue create \
  --repo camunda/camunda \
  --title "TITLE HERE" \
  --body "$(cat <<'EOF'
BODY HERE
EOF
)" \
  --label "kind/bug" \
  --label "component/COMPONENT"
```

Then set the GitHub Issue Type to "Bug" via GraphQL (it is not a label):

```bash
ISSUE_ID=$(gh api repos/camunda/camunda/issues/ISSUE_NUMBER --jq '.node_id')
gh api graphql -f query="
mutation {
  updateIssue(input: {
    id: \"$ISSUE_ID\",
    issueTypeId: \"IT_kwDOACVKPs4ABBrF\"
  }) {
    issue { number title }
  }
}"
```

Report the issue URL once created.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Including raw UUIDs from log fields | Every UUID must be evaluated — redact if customer-facing |
| Copying `jsonPayload.message` verbatim | Scan for embedded IDs first |
| Skipping the draft review step | Always stop and show the draft before creating |
| Creating the issue before approval | Never. Draft first, wait for "go ahead" |
| Leaving "8.8.21" placeholder when version is in logs | Populate from logs if available |
| Using `fix:` prefix in issue title | Issue titles are descriptive, not conventional-commit format |
| Wrapping component in title, e.g. `[Gateway] ...` | No brackets or component prefix — just a plain descriptive sentence |
| Adding `type: bug` as a label | "Bug" is a GitHub Issue Type, not a label — set it via GraphQL after creation |
