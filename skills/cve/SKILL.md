---
name: cve
description: Use when invoked as /cve <CVE-ID> <version> [<version>...] — per-version exploitability, fix PRs and next patch release date for camunda/camunda. Only for explicit /cve invocations.
---

# CVE Assessment per Version

Assess one CVE against specific Camunda versions: is it exploitable on each, is a fix merged, and which patch release ships it when.

## Argument

`/cve <CVE-ID> <version> [<version>...]` — e.g. `/cve CVE-2026-118259 8.8 8.9 8.10`. Each `<version>` is a minor (`8.8`) or a patch (`8.8.3`). If the CVE ID or no version was given, ask for them before continuing.

Normalize each version into two refs:

- **Analysis ref** — tag `X.Y.Z` when a patch was given, otherwise `origin/stable/X.Y`.
- **Fix ref** — always `origin/stable/X.Y`.

A version with no matching branch or tag (`gh api repos/camunda/camunda/branches/stable/X.Y`) gets the row `Unknown version` in the table; do not analyse it.

The user has stated that the vulnerable release exists in every version they pass in. Do not verify version ranges; assess only whether it is exploitable.

## Step 1 — CVE facts

**REQUIRED SUB-SKILL:** Use `eng-kit:cve-assessor` for its data sources (OSV.dev, GHSA, NVD) and its exploit-precondition reasoning. Use it only to learn: affected library or component, vulnerable class/feature, CVSS vector, attack preconditions, and upstream fixed version. Skip its dependency/version scan and its report template; this skill's output replaces it.

## Step 2 — Exploitable per version

Verdicts are per version because architecture, config defaults and exposed endpoints differ between minors.

`gh search code` only indexes the default branch, so it says nothing about `stable/*`. Read the code at each ref, cheapest route first. Never `git grep` a blobless clone: it fetches every blob under the pathspec and hangs.

1. **Manifests and single files** (poms, `application.properties`, one class): `gh api -H 'Accept: application/vnd.github.raw' 'repos/camunda/camunda/contents/<path>?ref=<branch-or-tag>'`.
2. **Locating files**: save `gh api 'repos/camunda/camunda/git/trees/<ref>?recursive=1'` to a file in the scratchpad, confirm `.truncated` is `false` (otherwise paths are missing), then `jq -r '.tree[].path'` and grep it; fetch the hits with step 1.
3. **Content grep across sources**: if the current directory is a camunda/camunda clone (`git remote -v`), `git fetch origin stable/X.Y` and `git grep -n -E '<pattern>' origin/stable/X.Y -- <paths>`. Otherwise `git clone --depth 1 --single-branch --branch <stable/X.Y or tag> --no-tags https://github.com/camunda/camunda.git <scratchpad>/camunda-X.Y` per version, and run `git config gc.auto 0` inside the clone. These API routes usually make a clone unnecessary. No builds.

For each version, decide from the code at that ref:

- Is the library or feature present and used in a way that reaches the vulnerable path? A library that is only version-pinned in the BOM does not count until a shipped component (the `dist` module, a component pom) consumes it and feeds it attacker-reachable input.
- Does the CVE's precondition hold: endpoint exposed to untrusted callers, config enabled by default or commonly, auth required, gateway in front, input actually attacker-controlled?
- **JDK or OS-package CVEs** have no library to grep: read the base images at the ref (`Dockerfile`, `camunda.Dockerfile`, per-component Dockerfiles, `apk add` lines) and compare the shipped JDK/package version with the CVE's affected versions. Add this reading to the verdict, and note which inbound or outbound paths (TLS, XML parsing, …) reach the vulnerable component.
- Components in scope: Zeebe (broker/gateway), Operate, Tasklist, Identity, Optimize (≥ 8.8 in the monorepo), distributions (Helm, C8Run, Docker image OS layer).

Every verdict names the concrete precondition that makes it exploitable or not, e.g. "REST `/v2/…` accepts multipart upload unauthenticated" or "JDBC pool only used with `JdbcJobStore`, which Camunda never configures". "Library present" alone is not a verdict.

## Step 3 — Fix PRs

```bash
gh pr list -R camunda/camunda --state all --search "<CVE-ID>" --json number,title,baseRefName,state,mergedAt,url,mergeCommit
gh pr list -R camunda/camunda --state all --limit 50 --search "<library> in:title" --json number,title,baseRefName,state,mergedAt,url,mergeCommit
```

Run both, using the library's short name (e.g. `opentelemetry`; for a JDK CVE, `temurin` or `jdk` with `--base stable/X.Y` to cut Renovate noise from other branches): Renovate and backport PRs often omit the CVE ID. Keep only PRs that bump to the CVE's fixed version or patch the affected code path; earlier bumps of the same library, or PRs for a different CVE, are not fixes. Put those in the *Fix PR(s)* cell as `None (related, not a fix: #<n>)` so a reader does not mistake them for one. Map each to a version by `baseRefName` (`stable/X.Y`); a PR into `main` maps to no released version. Record each PR as `#<n> (merged|open|closed)`.

## Step 4 — Next patch version

The root `pom.xml` on the stable branch carries the next unreleased patch:

```bash
gh api -H 'Accept: application/vnd.github.raw' 'repos/camunda/camunda/contents/pom.xml?ref=stable/X.Y' | grep -m1 -E '<version>[0-9]+\.[0-9]+\.[0-9]+-SNAPSHOT</version>'
gh api 'repos/camunda/camunda/git/matching-refs/tags/X.Y.' --paginate -q '.[].ref' | grep -E '/X\.Y\.[0-9]+$' | sort -V | tail -1
```

Next patch = the SNAPSHOT version without the suffix; if a tag with that exact number already exists, use tag + 1.

If a fix PR is merged, find the patch that already shipped it: `git tag --contains <mergeCommit> | grep -E '^X\.Y\.[0-9]+$' | sort -V | head -1` (needs a clone; with the API only, `gh api repos/camunda/camunda/compare/<tag>...<mergeCommit> -q .status` returns `behind` or `identical` when the tag contains it). An empty result means the fix has not shipped yet.

## Step 5 — Release date (fetch live, never hardcode)

```bash
gh api 'repos/camunda/company-handbook/contents/departments/products/product-management/product-operations/products-processes/release-management-process/c8-release-train/index.md' -q .content | base64 -d
```

Read only the `### Upcoming releases` table. Patch releases ship on every row's **Official Release** date (second Tuesday of the month), alongside the alpha/minor.

- **Next release row**: the first row whose Official Release date is on or after today.
- **Cut-off**: the patch Monorepo train starts on that row's **C8 Release Train Start** date. A fix merged on or before that date is in the next patch; merged after it, it lands in the following month's patch (take the next row). Treat this as an estimate and say so.
- **Table footnotes**: ignore the `*` markers; they only explain early feature freezes.
- **Support** (decide per version):
  1. The three newest *released* minors (excluding the in-development alpha line) are in standard support and get the monthly patch.
  2. An older minor is in extended support only if it appears in the ESUP case registry (`departments/products/engineering/processes-technical-processes-and-standards/standard-and-extended-support-periods/esup-case-registry/index.md`, same repo and `gh api` form). Show the patch number with `ESUP until <date>` in the Next patch cell, using the latest `Until` date among that version's rows, and note that the scope is per customer. ESUP versions are not on the release train: they have no scheduled patch releases, so the Release date cell is `Ad-hoc (not scheduled)` and the cut-off logic does not apply.
  3. Otherwise the version is `EOL`: put `EOL` in the Next patch and Release date columns and do not invent a patch.

## Step 6 — Output

Give exactly this, in this order. No other sections.

**Answers** — up to 4 sentences, one per point, covering in order:

1. Affected in any version? `Yes` or `No`; exploitable, not just present by version.
2. Why or why not.
3. Impact: what an attacker can do. `n/a` when not affected.
4. Likelihood of exploitation. `n/a` when not affected.

Question 5 (next patch and release date per version) is answered by the table.

**Table** — one row per input version:

| Version | Exploitable | Why | Fix PR(s) | Next patch | Release date | Fix in next patch? |
|---|---|---|---|---|---|---|

- *Exploitable*: `Yes` / `No`.
- *Why*: one line with the concrete precondition.
- *Fix PR(s)*: linked PRs with state, or `None`.
- *Fix in next patch?*: `Already in X.Y.Z` / `Yes` / `No — merged after cut-off` / `No fix`. For ESUP versions with a merged, unreleased fix: `Yes, in next ad-hoc patch`. For `EOL` versions: `No fix`.
- *Release date*: the Official Release date, suffixed `(estimate)` when it comes from the table cut-off logic; `Ad-hoc (not scheduled)` for ESUP versions; `EOL` for EOL versions.

Note any check that could not be completed (API failure, ref not fetchable) under the table in one line.

## Quick reference

| Need | Source |
|---|---|
| CVE data | `eng-kit:cve-assessor` sources |
| Code per version | `git grep`/`git show` on `origin/stable/X.Y` or tag |
| Fix PRs | `gh pr list -R camunda/camunda --search` |
| Next patch | root `pom.xml` SNAPSHOT version on the stable branch |
| Dates, cut-off | company-handbook `c8-release-train/index.md` |
| Support status | three newest released minors; else ESUP case registry |
