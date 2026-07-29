---
name: daily-update
description: Use when generating Remco's daily standup update for Slack. Fetches yesterday's Outlook meetings, Slack incident/support involvement, and GitHub PRs (authored + reviewed), and posts the update as a draft reply in today's team-core-features-bravo standup thread.
model: claude-sonnet-5
effort: xhigh
---

# Daily Standup Update

## Overview

This skill generates Remco Westerhoud's (remco.westerhoud@camunda.com, GitHub: remcowesterhoud)
daily standup update for the team Slack channel. It resolves the correct "yesterday" window
(skipping weekends, Dutch public holidays, and PTO days), fetches data from Outlook, Slack, and
GitHub, prompts for today's goals, and posts the update as a draft reply in today's standup thread
in #team-core-features-bravo.

**Owner:** remco.westerhoud@camunda.com

---

## Step 1 — Resolve the Report Window (and self-heal holidays)

### 1a. Self-heal: ensure current year's holidays are present

Before walking backward, run:

```bash
date +%Y
```

Check whether the Dutch holiday table below contains entries for the returned year. If not, stop
execution, compute that year's holidays using the rules in the table header, edit this SKILL.md to
add the new entries under the appropriate year heading, save the file, then continue.

### 1b. Walk backward to find "yesterday"

Run:

```bash
date +%Y-%m-%d
```

Starting from today's date, walk backward day-by-day:

1. Skip any day that is a **Saturday** (weekday 6) or **Sunday** (weekday 7).
2. Skip any day whose date matches an entry in the Dutch holiday table below.
3. Skip any day where Remco's Outlook calendar shows a PTO/OOF event — any event title containing
   (case-insensitive) `PTO`, `Out of office`, `OOO`, `Vacation`, `Holiday`, or where Outlook's
   `showAs` status is `oof`. Query Outlook via `mcp__claude_ai_Microsoft_365__outlook_calendar_search`
   (see Step 4a for the query form) and inspect the results before landing.
4. The first non-skipped day is **"yesterday"** for the report.

Track every day skipped between today and the landing day. Each becomes a bullet in the yesterday
section:
- Skipped because Saturday/Sunday → no bullet (weekends are not reported).
- Skipped because Dutch public holiday → `- Public Holiday — <holiday name>`.
- Skipped because PTO/OOF → `- PTO`.

### Dutch holiday table

**If no entries exist for the current calendar year when this skill runs, stop and add them by
editing this SKILL.md before continuing. Use Easter Sunday math (Goede Vrijdag = Easter − 2,
Tweede Paasdag = Easter + 1, Hemelvaartsdag = Easter + 39, Eerste Pinksterdag = Easter + 49,
Tweede Pinksterdag = Easter + 50). Koningsdag is April 27 unless that falls on a Sunday, then
April 26. Liberation Day (May 5) is only a day off every 5 years — include it for 2025, 2030,
2035, etc.**

| Date       | Name                  |
|------------|-----------------------|
| 2026-01-01 | Nieuwjaarsdag         |
| 2026-04-03 | Goede Vrijdag         |
| 2026-04-05 | Eerste Paasdag        |
| 2026-04-06 | Tweede Paasdag        |
| 2026-04-27 | Koningsdag            |
| 2026-05-14 | Hemelvaartsdag        |
| 2026-05-24 | Eerste Pinksterdag    |
| 2026-05-25 | Tweede Pinksterdag    |
| 2026-12-25 | Eerste Kerstdag       |
| 2026-12-26 | Tweede Kerstdag       |
| 2027-01-01 | Nieuwjaarsdag         |
| 2027-03-26 | Goede Vrijdag         |
| 2027-03-28 | Eerste Paasdag        |
| 2027-03-29 | Tweede Paasdag        |
| 2027-04-27 | Koningsdag            |
| 2027-05-06 | Hemelvaartsdag        |
| 2027-05-16 | Eerste Pinksterdag    |
| 2027-05-17 | Tweede Pinksterdag    |
| 2027-12-25 | Eerste Kerstdag       |
| 2027-12-26 | Tweede Kerstdag       |

---

## Step 2 — Ask "How do you feel today?"

Use the `AskUserQuestion` tool for this — Remco prefers the interactive prompt over plain
conversational text for every question in this skill, including open-ended ones. Offer 3-4
plausible mood options (vary them each run — e.g. `Good`, `Tired`, `Stressed`, `Great`, `Meh`);
the tool's built-in "Other" choice always lets Remco type an exact free-text answer instead, so
this still captures any mood, not just the ones offered.

> How do you feel today?

Capture their response verbatim (whichever option or free-text they gave). The enhancement
happens later in Step 7 once the workspace's custom emoji list has been fetched in Step 4g.

---

## Step 3 — Load Required Tools

The Glean, Microsoft 365, and Slack MCP tools are deferred and their schemas are not loaded by default.
Before making any calls, invoke `ToolSearch` with:

```
select:mcp__claude_ai_Glean__search,mcp__claude_ai_Glean__read_document,mcp__claude_ai_Glean__user_activity,mcp__claude_ai_Microsoft_365__outlook_calendar_search,mcp__claude_ai_Slack__slack_search_public_and_private,mcp__claude_ai_Slack__slack_read_thread,mcp__claude_ai_Slack__slack_search_channels,mcp__claude_ai_Slack__slack_search_emojis,mcp__claude_ai_Slack__slack_send_message_draft,mcp__claude_ai_Slack__slack_send_message
```

Wait for the schemas to be returned before continuing to Step 4.

---

## Step 4 — Fetch Data in Parallel

Make all of the following tool calls in a **single message** so they run concurrently.

### Event exclusion list

The following event titles are excluded from meeting output (case-insensitive substring match).
Edit this list in the SKILL.md to add more entries over time:

```
Lunchtime blocker
```

### 4a. Outlook meetings for yesterday

Use `mcp__claude_ai_Microsoft_365__outlook_calendar_search` as the **primary** source for
calendar events. Query for events on yesterday's date. This tool reliably returns accepted,
tentative, and declined meeting invitations with title, start time, and response status.

Also call `mcp__claude_ai_Glean__user_activity` as a **fallback** — it may surface meeting
documents or other activity not captured by the calendar API. Reconcile both responses: union the
results, deduplicate by event title + start time.

Do **not** use `mcp__claude_ai_Glean__search` with `app: "outlook"` for calendar events —
Glean's Outlook index does not reliably return calendar entries.

Apply these filters in order:

1. **Medic detection (runs first, overrides meeting list):** If any event title contains
   `Zeebe Medic Schedule` (case-insensitive), set `was_medic_yesterday = true` and remove the
   event from the meeting list. It becomes its own top-level bullet `- Medic duties` in the
   rendered output — it is never nested under Meetings.

   **Fallback:** The `Zeebe Medic Schedule` event is an all-day event and may not be returned by
   the calendar query. If it is absent, check yesterday's standup thread (Step 4e) — if the
   "What are your goals for today?" section contains a `Medic duties` bullet, set
   `was_medic_yesterday = true` as well.

2. **Exclusion list:** Drop any event whose title is a case-insensitive substring match against
   the exclusion list above (e.g. `Lunchtime blocker`).

3. **Standard filters:**
   - Drop all-day events.
   - Drop cancelled events.
   - Drop events the user declined. Keep accepted and tentative-accepted.

Surviving events become nested bullets under `- Meetings`.

### 4b. Slack involvement for yesterday

Use `mcp__claude_ai_Slack__slack_search_public_and_private` in **two passes**. Remco's Slack
user ID is `U02CYMDAYE8`.

**Pass 1 — messages posted by me:**
- `query: "from:<@U02CYMDAYE8> on:<yesterday-date>"`
- `sort: "timestamp"`
- `channel_types: "public_channel,private_channel"`

**Pass 2 — @-mentions of me:**
- `query: "@Remco Westerhoud on:<yesterday-date>"`
- `sort: "timestamp"`
- `channel_types: "public_channel,private_channel"`

Replace `<yesterday-date>` with the resolved date in `YYYY-MM-DD` format.

**Important:** Always use `on:DATE` for same-day filtering. Do **not** use `after:DATE before:DATE`
with the same date — those modifiers are mutually exclusive (nothing can be both after and before
the same day) and Slack returns results from surrounding days instead of the target date.

### Slack channel exclusion list

The following channel names are excluded from output (case-insensitive exact match).
Edit this list in the SKILL.md to add more entries over time:

```
support-sparring-zeebe
```

For each result across both passes, extract the channel name from the message metadata.
Keep only channels whose names match one of these prefixes (case-insensitive):
- `inc-`
- `cve-`
- `prj-`
- `inc-support-`
- `support-`

Then drop any channel that matches the exclusion list above.

Deduplicate by channel name. Each surviving channel becomes a top-level bullet using Slack channel
mention syntax `<#CHANNEL_ID|channel-name>` (e.g. `<#C0B8UC070NB|inc-rest-connector-...>`).
Always extract the channel ID from the Slack search metadata alongside the name — plain `#name`
text does **not** auto-link when posted via the API.
If a PR or issue reference is directly tied to that channel, add it as a nested bullet —
otherwise omit sub-bullets.

### 4c. GitHub PRs authored yesterday

```bash
gh search prs --author=@me --created=<yesterday-date>..<yesterday-date> --json number,title,url,state,isDraft
```

Replace `<yesterday-date>` with the resolved date in `YYYY-MM-DD` format. Exclude draft PRs
(`isDraft == true`) from the authored list.

### 4d. GitHub PRs reviewed yesterday

Use the GitHub GraphQL contributions API — it records every review submitted on a specific date
regardless of PR state or author:

```bash
gh api graphql -f query='
{
  user(login: "remcowesterhoud") {
    contributionsCollection(
      from: "<yesterday-date>T00:00:00Z"
      to:   "<yesterday-date>T23:59:59Z"
    ) {
      pullRequestReviewContributions(first: 50) {
        nodes {
          pullRequest { number title url }
        }
      }
    }
  }
}'
```

Replace `<yesterday-date>` with the resolved date in `YYYY-MM-DD` format. Deduplicate by PR
number (multiple review rounds on the same PR count once). Each result becomes a nested bullet
under a `- PRs reviewed` goal line, or plain unplanned activity if reviewing wasn't a stated goal.

### 4e. Yesterday's standup post (for goal comparison)

Use `mcp__claude_ai_Slack__slack_search_public_and_private` to find Remco's standup post from
yesterday in `team-core-features-bravo`:

- `query: "from:<@U02CYMDAYE8> in:#team-core-features-bravo accomplished yesterday on:<yesterday-date>"`
- `sort: "timestamp"`

From the result, extract `channel_id` and `message_ts` of the matching message.

Then call `mcp__claude_ai_Slack__slack_read_thread` with that `channel_id` and `message_ts` to
fetch the full thread content. Parse the section under `What are your goals for today?` — those
bullets are the goals to compare against today.

If no standup post is found (e.g. Remco was off or forgot), skip the goal-comparison step
entirely; render the accomplished-yesterday section from raw activity data as before.

### 4g. Workspace custom emoji list

Call `mcp__claude_ai_Slack__slack_search_emojis` with an empty or wildcard query to retrieve the
workspace's custom emoji names. Store the result as `custom_emoji_list` for use in Step 7.

---

## Step 4f — Classify Yesterday's Goals (✅ / 🔄 / ❌)

For each goal extracted in 4e, classify based on the activity data collected in 4a–4d:

| Status                | Emoji shortcode         | When to apply                                                                                   |
|-----------------------|-------------------------|--------------------------------------------------------------------------------------------------|
| Completed             | `:white_check_mark:`    | Clear evidence the goal was finished — PR merged, meeting attended, channel resolved, etc.        |
| In progress           | `:loading:`             | Partial evidence — PR opened but not merged, conversation started but not concluded, etc.         |
| Not done              | `:x:`                   | No evidence at all of activity related to the goal                                                |

**Classification heuristics:**

- Goal references a specific PR/issue number → check the PR/issue state and Remco's activity on
  yesterday-date. Merged/closed → ✅. Touched but open → 🔄. Untouched → ❌.
- Goal references a meeting/sync → ✅ if the meeting appears in the calendar data (4a).
- Goal references a Slack channel (e.g. `#inc-support-NNNNN`) → ✅ if Remco posted there
  yesterday, 🔄 if only mentioned in passing, ❌ if no activity.
- Generic goals like "Review PRs" → ✅ if any PRs were reviewed (4d data), ❌ otherwise.
- Anything else → mark as **uncertain** and surface to the user for confirmation.

**Always surface uncertain classifications to the user** using AskUserQuestion with Done /
In progress / Not done options. Do not silently guess. Apply the user's answer before rendering.

**Review-item handling (special case):** Review-PR bullets that appeared in yesterday's standup
are often auto-scaffolded leftovers rather than genuine plans. When a review bullet would land as
❌ (no evidence the review happened), **omit it entirely** instead of rendering ❌. The principle:
*if Remco didn't plan it and didn't do it, it's not relevant.* The same review may have come from
the previous day's "PRs assigned to me" scaffold (Step 5c) rather than a conscious goal, so
trailing it forward as a failure is noise. Only render ❌ for goals Remco actively chose. If in
doubt whether a review was a real plan vs. a scaffold leftover, ask via AskUserQuestion.

The inverse holds too: if Remco *did* a review yesterday that wasn't in his stated goals, include
it under "Additional PR reviews" with ✅ (or as plain bullets without an emoji, matching the
template's "additional unplanned activity" pattern).

---

## Step 5 — Scaffold Today's Goals (best-effort)

Fetch all of the following in a **single message**.

### 5a. Today's accepted Outlook meetings

Same approach as 4a but with today's date. Use `mcp__claude_ai_Microsoft_365__outlook_calendar_search`
as the primary source, with `mcp__claude_ai_Glean__user_activity` as fallback. Apply the same
filter chain (medic detection → exclusion list → accepted/non-cancelled/non-all-day).

Set `is_medic_today = true` if a `Zeebe Medic Schedule` event is found today.

**Important:** `is_medic_today` is determined solely from today's calendar. It is **never**
inherited from `was_medic_yesterday` — medic is a 1-day shift, so being on rotation yesterday
says nothing about today.

### 5b. My open PRs needing my attention

`gh search prs` does not expose `reviewDecision` — use `gh pr list` instead:

```bash
gh pr list --author=@me --state=open --repo camunda/camunda --json number,title,url,reviewDecision
```

For each PR where `reviewDecision == "CHANGES_REQUESTED"`, suggest the goal:
`Apply review feedback to #NNNN — <title>`

### 5c. PRs assigned to me to review

```bash
gh search prs --review-requested=@me --state=open --repo camunda/camunda --json number,title,url
```

For each result, suggest the goal:
`Review #NNNN — <title>`

### 5d. Medic carry-over

If `is_medic_today == true`, include `- Medic duties` as the first bullet under today's section
(before Meetings).

---

## Step 6 — Preview Both Sections, Then Ask for Corrections

### 6a. Preview the accomplished-yesterday section

**First, print the scaffolded accomplished-yesterday section to the user in chat** so they can
review the goal classifications and any additional unplanned activity before confirming. Use a
short conversational format, e.g.:

> Here's what I have for yesterday (YYYY-MM-DD):
>
> - ✅ Medic duties  *(if was_medic_yesterday, with incident channel sub-bullets)*
> - ✅ Meetings: <comma-separated meeting titles>
> - ✅ / 🔄 / ❌ <goal with classification>
> - <unplanned activity if any>
>
> If a section has no items, say so explicitly.

**Then ask (via `AskUserQuestion`, see combined call below):**

1. > Does yesterday's section look correct? Anything to add, remove, or reclassify?
>
> Suggested options: `Looks good, no changes` (Recommended), `Needs changes`.

Apply any corrections before continuing. Treat answers literally — whether given by picking
`Needs changes` and then specifying details, or by going straight to `Other` with the correction
typed out directly (both are valid; don't make Remco pick a generic option first if he's already
typed the specific edit):
- "Add X to medic duties" → add X as a sub-bullet under the medic duties line in the accomplished section.
- "Remove X" → remove that bullet entirely.
- "Mark X as in progress" → change its status emoji to `:loading:`.
- "No" / "looks good" → proceed as-is.

### 6b. Preview today's goals

**Then print the scaffolded today's goals to the user in chat.** Use a short conversational
format, e.g.:

> Here's what I've scaffolded for today (YYYY-MM-DD):
>
> - Medic duties  *(if is_medic_today)*
> - Meetings: <comma-separated meeting titles>
> - Apply review feedback to #NNNN — <title>  *(per CHANGES_REQUESTED PR)*
> - Review #NNNN — <title>  *(per review-requested PR)*
>
> If a section has no items, say so explicitly (e.g. "No meetings on the calendar today.").

**Then ask (via `AskUserQuestion`, see combined call below):**

2. > Any additional goals to add to today?
>
> Suggested options: `No additional goals` (Recommended), `Add goals`.

Append additional goals as bullets at the end of the today section. If the answer is "no",
"nothing", "nope", or empty, skip that addition.

### 6c. Ask about missed incident channels

**Ask one final question (via `AskUserQuestion`, see combined call below):**

3. > Were you involved in any incident channels (#inc-support-*, #inc-*, #cve-*) yesterday that didn't show up in the accomplished section?
>
> Suggested options: `No incidents missed` (Recommended), `Yes, missed one`.

For any incident channels named, add them as sub-bullets under the medic duties line in the
accomplished-yesterday section (or as standalone top-level bullets if there was no medic duties
goal). If the answer is "no", skip.

**All three questions must be asked together in a single `AskUserQuestion` call** (it supports up
to 4 questions at once) — never fall back to plain conversational text for these, even though
the answers are open-ended. The tool's per-question "Other" option always accepts free-text, so
open-endedness is not a reason to skip it.

---

## Step 7 — Assemble the Message

Assemble the standup message using standard markdown. It will be posted via the Slack API in
Step 8 — do **not** wrap it in a fenced code block. Use these formatting conventions:

- **Section headers**: `**bold**` markdown (e.g. `**How do you feel today?**`)
- **Top-level bullets**: `- ` (markdown list item — Slack renders this as a proper list)
- **Nested bullets**: `  - ` (two-space indent + dash — Slack renders this as an indented nested list item)

### Rendering rules

- **"How do you feel today?" enhancement:** Take the raw feel answer from Step 2 and spice it up
  before inserting it into the message. Keep the core sentiment and wording intact, but enhance
  it with:
  - One or two fitting emoji — **prefer custom workspace emoji from `custom_emoji_list`** (Step 4g)
    over standard Unicode emoji when a good match exists (e.g. `:bravo-team:`, `:thinking-foot:`,
    `:loading:`, `:crab:`, or any mood-relevant custom emoji). Fall back to standard emoji
    (`:coffee:`, `:sleeping:`, `:muscle:`, `:rainbow:`, `:brain:`) only if no custom emoji fits.
    Pick based on the mood, not randomly.
  - Optionally: a short fun quote, a relatable observation, or a one-liner that matches the vibe —
    something that makes teammates smile.
  Keep the enhancement brief (1–3 sentences total). Do not change the meaning or be sarcastic about
  how the user feels. The goal is warmth and personality, not jokes at their expense.

- **Skip the `- Meetings` block entirely** if there are zero meetings after filtering — do not
  print an empty header bullet.
- **Skip `- PRs authored` / `- PRs reviewed`** lines if those lists are empty.
- **PR / issue references:** render as `<URL|title>` (Slack hyperlink syntax), e.g.
  `<https://github.com/camunda/camunda/pull/54455|fix: restore getMessageKeys on MessageBatchRecordValue>`.
  Always include the PR/issue title so the reader knows what it is without clicking.
  Use `/pull/NNNN` for PRs and `/issues/NNNN` for issues.
- **Slack channel references:** always use Slack's channel mention syntax `<#CHANNEL_ID|channel-name>`
  (e.g. `<#C0B8UC070NB|inc-rest-connector-no-longer-building-request-body-saas-likely-feel-mapping>`).
  Plain `#channel-name` text does **not** create a clickable link when sent via the API — only the
  `<#ID|name>` form does. Pull both the ID and the full name from the Slack search metadata (Step 4b)
  or from yesterday's standup thread (Step 4e) — never abbreviate the name or omit the ID.
- **Empty yesterday section:** If after all filtering the yesterday section has no bullets AND
  there are no skipped-day bullets, emit a warning to the user before assembling:
  "No activity detected for <date>. Are you sure that was a working day?" — then still assemble
  the message with empty sections.
- **Blockers:** Always emit `No` unless the user mentioned a blocker in conversation. If they did,
  use their wording verbatim.

### Exact template

**The "accomplished yesterday" section is goal-driven:** Each line lists one of yesterday's
goals (from 4e) as a bullet followed by its status emoji shortcode
(`:white_check_mark:`, `:loading:`, or `:x:`) and then the goal text. Slack converts the
shortcode to an emoji on send.

**When a goal fans out into multiple items** (e.g. "Review PRs" → four PR references), put the
goal headline on the bullet line and each item on its own nested `  -` line. For
single-item evidence, append the reference inline in parentheses instead.

Activity that wasn't part of yesterday's stated goals but is still worth mentioning (e.g. an
unplanned PR or meeting) goes underneath as plain bullets without a status emoji.

```
**How do you feel today?**
<spiced-up feel answer — enhanced in Step 7 using custom_emoji_list from Step 4g>

**What have you accomplished yesterday?**
<skipped-day bullets here if any, e.g.:>
- Public Holiday — Eerste Paasdag
- PTO
<"- Medic duties" if was_medic_yesterday == true>
- :white_check_mark: <yesterday goal completed> (<optional context — #PR, channel, etc.>)
- :loading: <yesterday goal in progress> (<optional context>)
- :x: <yesterday goal not done>
- :white_check_mark: <goal that fans out into multiple items>
  - <https://github.com/camunda/camunda/pull/NNNN|title>
  - <https://github.com/camunda/camunda/pull/NNNN|title>
<additional unplanned activity, if notable:>
- Extra meeting/PR/channel that wasn't a stated goal

**What are your goals for today?**
<"- Medic duties" if is_medic_today == true>
- Meetings
  - <meeting title>
- Apply review feedback to #NNNN — <https://github.com/camunda/camunda/pull/NNNN|title>
- Review #NNNN — <https://github.com/camunda/camunda/pull/NNNN|title>
<user-supplied additional goals as bullets>

**Are you running into any blockers?**
No
```

**Fallback (no standup found yesterday):** If Step 4e returned nothing (Remco was off, forgot to
post, or it's the first run), render the accomplished-yesterday section the old way — bullets
for Meetings, Slack channels, PRs authored, PRs reviewed, without status emojis. Inform the user
that no prior standup was found.

---

## Step 8 — Review in Chat, Then Post

**Do NOT use `slack_send_message_draft`** — it stores content as literal Unicode characters
rather than proper Slack list blocks, causing duplicate bullets when Slack renders the message.
Instead, show the message here in the chat for review, wait for confirmation, then send directly.

### 8a. Find the channel and today's thread

Run both in a **single parallel message**:

1. `mcp__claude_ai_Slack__slack_search_channels` with `query: "team-core-features-bravo"` — get
   the channel ID.
2. `mcp__claude_ai_Slack__slack_search_public_and_private` with
   `query: "in:#team-core-features-bravo on:<today-date>"`, `sort: "timestamp"`,
   `sort_dir: "asc"` — find today's standup thread starter and extract its `message_ts`.

### 8b. Show message in chat for review

Print the fully assembled message to the user in the chat (inside a fenced code block so
formatting is visible), then ask: "Ready to send, or any changes needed?"

Wait for the user's go-ahead before proceeding. If they request changes, apply them and show
the updated message again before asking once more.

### 8c. Send directly to the thread

Once the user confirms, call `mcp__claude_ai_Slack__slack_send_message` with:
- `channel_id`: from 8a
- `thread_ts`: the `message_ts` from 8a (so it posts as a reply in today's standup thread)
- `message`: the confirmed message

If no thread was found yet (bot hasn't posted it yet):
- Tell the user: "No standup thread found yet for today in #team-core-features-bravo. Posting as a new top-level message instead."
- Call `mcp__claude_ai_Slack__slack_send_message` with `channel_id` only (no `thread_ts`).

### 8d. Confirm to the user

Reply with the message link returned by `slack_send_message`.

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Including the `Zeebe Medic Schedule` event inside the Meetings block | Medic events must only appear as `- Medic duties`, never nested under Meetings |
| Listing draft PRs under authored | Exclude `isDraft == true` from the authored list |
| Rendering review-PR bullets as ❌ when there's no evidence Remco reviewed them | Omit the review entirely. If Remco didn't plan it and didn't do it, it's not relevant noise. Only render ❌ for goals he actively chose, not scaffold leftovers from yesterday's "PRs assigned to me" list. See Step 4f's "Review-item handling (special case)". |
| Skipping the standup fetch in Step 4e | The "accomplished yesterday" section is supposed to mirror yesterday's stated goals with status emojis — without 4e there's no goal list to compare against |
| Silently guessing ✅/🔄/❌ for ambiguous goals | Always surface uncertain classifications to the user via AskUserQuestion — never assume |
| Using Unicode emoji ✅ / ❌ instead of the Slack shortcodes | Use the literal shortcodes `:white_check_mark:`, `:loading:`, `:x:` — `:loading:` is a custom workspace emoji with no Unicode equivalent, and Slack converts shortcodes on send |
| Using plain `#channel-name` text for Slack channels | Plain `#name` does not link when sent via the API. Always use `<#CHANNEL_ID|channel-name>` — pull both the ID and full name from Slack search metadata (Step 4b) or yesterday's standup thread (Step 4e) |
| Rendering PRs with no title or no URL | Always include both using Slack hyperlink syntax: `<https://github.com/.../pull/NNNN|title>` — the title tells readers what it is, the URL makes it clickable |
| Using `gh search prs ... --json reviewDecision` | `gh search prs` does not expose `reviewDecision`; use `gh pr list` for that query (Step 5b) |
| Asking for additional goals without previewing the scaffolded ones | Step 6 requires printing the scaffolded today's goals to chat first so the user can decide what to add |
| Printing an empty `- Meetings` header | Skip the entire block when the meeting list is empty after filtering |
| Stripping all personality from the "feel" answer | Keep the user's core sentiment but enhance it with fitting emoji and an optional fun line — see Step 2 |
| Using Glean search for Outlook calendar events | Use `mcp__claude_ai_Microsoft_365__outlook_calendar_search` — Glean's Outlook index does not reliably return calendar entries. Never use `app: "outlook"` in a Glean search for meetings. |
| Including `#support-sparring-zeebe` in the accomplished section | This is a general sparring/discussion channel, not an active support case. It is on the Slack channel exclusion list. |
| Forgetting to load Glean, M365, and Slack tool schemas in Step 3 | ToolSearch must be called before any `mcp__claude_ai_Glean__*`, `mcp__claude_ai_Microsoft_365__*`, or `mcp__claude_ai_Slack__*` call |
| Running 4a–4e sequentially | All fetches in Step 4 must be issued in a single parallel message |
| Skipping the holiday self-heal check | Always verify the current year has entries before walking backward |
| Adding timestamps to meeting bullets (e.g. `  - Team Sync — 10:00`) | Render meeting titles only — no time suffix |
| Using Glean `app: "slack"` for Step 4b Slack search | Use `slack_search_public_and_private` instead — native Slack search supports proper date filters and searches private channels reliably |
| Using Glean + `read_document` for Step 4e standup fetch | Use `slack_search_public_and_private` + `slack_read_thread` — more reliable, no indexing lag, returns full thread content |
| Using `slack_send_message_draft` | Do not use drafts — they store content as literal Unicode characters, causing duplicate bullets. Always use `slack_send_message` after user confirms in chat. |
| Posting directly without showing the message in chat first | Always show the assembled message in a fenced code block in chat and wait for the user's go-ahead before calling `slack_send_message` |
| Posting the message as a new top-level message when today's thread exists | Use `thread_ts` from 8a so the message is posted as a reply in today's standup thread, not as a standalone message |
| Running Steps 8a searches sequentially | The channel lookup and thread search in Step 8a must run in a single parallel message |
| Using `after:DATE before:DATE` for same-day Slack search | Those modifiers are mutually exclusive — use `on:DATE` instead. The combined form returns messages from surrounding days and silently misses the target date entirely. |
| Using `gh search prs --reviewed-by=@me` to find yesterday's reviews | That returns all open PRs you've ever reviewed, not ones reviewed on a specific date. Use the GraphQL `contributionsCollection` query in Step 4d instead. |
| Missing closed issues in the accomplished section | `gh search prs --created=DATE` only finds PRs authored that day; closed issues are invisible to it. Closed issues appear in Glean `user_activity` or in the yesterday standup post — check those sources and ask the user in Step 6a if uncertain. |
| Asking Step 2 or Step 6 questions in plain conversational text | Remco prefers the `AskUserQuestion` interactive prompt for every question in this skill, even open-ended ones — the tool's built-in "Other" choice covers free-text answers, so open-endedness is never a reason to fall back to plain text. |
