# Daily Update — Learning Protocol

Referenced by `SKILL.md` Step 0 (load), Steps 4f/6/8 (correction ledger), Step 7 (apply + size
guard) and Step 9 (evaluate and persist). Goal: fewer user corrections over time, without the
message growing.

## State location

`~/.claude/daily-update-state/` — deliberately **outside** the skill directory. It holds Slack
channel names, PR titles and meeting names, and `~/.claude` is a git repo with a GitHub remote. The
repo's `.gitignore` ignores unknown paths, so the state dir is never committed. Consequence: state
is not synced across machines.

- `runs.json` — run history and counters (schema below).
- `examples/YYYY-MM-DD.md` — max 5 example messages (format below).
- `lessons.md` — headings `## Keep doing` and `## Avoid`; at most 10 bullets in total; each bullet
  `- <lesson> (seen N×, last YYYY-MM-DD)`.

### runs.json

```json
{
  "seeded": false,
  "size_budget": {"max_lines": 30, "max_chars": 2000, "calibrated": false},
  "totals": {"runs": 0, "sent": 0, "corrections": 0, "zero_change_runs": 0},
  "runs": [
    {
      "date": "2026-01-01",
      "sent": true,
      "day_tags": ["normal"],
      "change_count": 1,
      "corrections": [{"step": "6a", "kind": "reclassify", "note": "goal X was in progress, not done"}],
      "clarifications": 0,
      "added_goals": 1,
      "lines": 22,
      "chars": 1400,
      "within_budget": true,
      "example_action": "added",
      "evaluation": "One reclassify in 6a; within budget; structure matches examples."
    }
  ]
}
```

- `runs` is newest last, max 20 entries (ring buffer).
- `date` is the report date (YYYY-MM-DD). `day_tags` e.g. `normal`, `medic`, `post-holiday`,
  `post-pto`, `heavy-review`.
- `corrections[].step` is `6a|6c|8b`; `kind` is `reclassify|add|remove|rewrite|size|format|other`.
- `example_action` is `"added"`, `"replaced <file>"` or `"none"`.

### examples/YYYY-MM-DD.md

YAML frontmatter plus the body.

```
---
date: 2026-01-01
status: real            # real | seed
change_count: 1         # int, or unknown for seeds
provisional: false      # true if change_count > 2 or status is seed
lines: 22
chars: 1400
day_tags: [normal]
corrections: []         # short summary list, or empty
---
<the message exactly as sent (post-correction = what the user actually wanted)>
```

### Bootstrap

If the directory or any file is missing, create it with the empty defaults: `runs.json` as the
sample above with `"runs": []`, `lessons.md` with the two headings and no bullets, and an empty
`examples/` directory.

## Correction ledger (what counts as a change)

During the run keep an in-conversation ledger `corrections` (starts as `[]`). Append one entry for
each thing the user changes after the skill's draft:

- a reclassify / add / remove / rewording in Step 6a,
- each missed incident channel in Step 6c,
- each distinct edit requested in Step 8b.

"Looks good" / no changes = 0. `change_count = len(corrections)`. If the user answers 6a/6c via
free text with several edits, write one ledger entry per edit.

**Not scored:** answers to the Step 4f "uncertain classification" questions (count in
`clarifications`) and goals the user adds in 6b (count in `added_goals`). These are inputs, not
mistakes. Both are still recorded in the run entry.

## Example policy

No absolute threshold (cold-start friendly). Every **sent** run is eligible. Ranking key, best
first: lower `change_count` (seed/`unknown` ranks worst), then fewer `chars`, then newer date.

- Fewer than 5 examples: add the run.
- 5 examples: compare the run to the worst-ranked example and replace it if the run ranks strictly
  better, or if `change_count` ties AND the run is within budget AND (it is smaller OR it adds a
  `day_tags` variety not present among the other examples). Seeds are always replaced first. Delete
  the replaced file. Record the decision and a one-line reason in `example_action` / `evaluation`.
- **Provisional** examples (`change_count` > 2, or seeds) are a reference for structure and size,
  and their `corrections` feed "Avoid" lessons, but they are not a stylistic gold standard.
  Non-provisional examples are the gold standard.

### Seed backfill (one-time, speeds up cold start)

If `runs.json.seeded == false` and fewer than 5 examples exist, in Step 9: search Slack for the
user's recent standup posts with `slack_search_public_and_private`, query
`from:<@U02CYMDAYE8> in:#team-core-features-bravo accomplished yesterday`, `sort: "timestamp"`,
roughly the last 3 weeks. Read each thread with `slack_read_thread` and keep up to (5 − current
count) of the most recent ones whose body has the three bold section headers of the template. Store
them as `status: seed`, `change_count: unknown`, `provisional: true`. Then set `seeded: true` (even
if none qualified). Read-only on Slack.

## Size budget

Initial `max_lines: 30`, `max_chars: 2000`. `lines` = non-empty lines of the final message.

Once >= 3 examples exist (seeds count) and `calibrated` is false or the examples changed: set both
limits to `round(1.2 × median of the examples)` and `calibrated: true`.

A final message over budget is a negative signal in the evaluation and is listed as a `kind: size`
finding. It is a user correction only if the user asked for it to be shorter. **Learning may never
grow the message:** a lesson that adds content must replace something else.

## Using the learning state (Step 0 + Step 7)

Step 0 loads lessons, examples and `size_budget` silently (do not print them). Before assembling
the message in Step 7, compare the draft with the non-provisional examples (section structure,
bullet style, wording of goals, how fan-outs are rendered, length) and apply the lessons. If a
lesson conflicts with an explicit rule in `SKILL.md`, `SKILL.md` wins and the conflict is reported
in Step 9.

## End-of-run evaluation (Step 9 procedure)

Keep this cheap: no extra user questions unless a `SKILL.md` edit is proposed.

**9a Measure.** Compute `lines` and `chars` of the final message (bash `wc` on a scratch file, or
count carefully in-model). Build the run entry. If the user never confirmed/sent, record
`sent: false` and skip example handling.

**9b Evaluate.** Compare with the examples and lessons.
- Went well: zero/low corrections, within budget, structure matches the examples.
- Could be better: each ledger entry, size over budget, deviations from the examples.
Write a one-sentence `evaluation`.

**9c Examples.** Apply the example policy above (including the one-time seed backfill), then
recalibrate the size budget if due.

**9d Lessons and improvements.**
- A one-off issue: add or refresh a line in `lessons.md`. Respect the cap of 10 bullets: merge
  similar lines, otherwise drop the lowest-count, oldest one.
- A correction of the same `kind` + topic that appears >= 2 times across `runs` (including this
  run): propose a concrete `SKILL.md` edit (Common Mistakes row or a rule tweak) via
  `AskUserQuestion` with options `Apply edit` / `Skip` / `Not now`. Apply with Edit only on
  approval. **Never edit `SKILL.md` without approval** (the Step 1a holiday self-heal is the only
  exception). Proposed edits must be concise and must not increase message length.

**9e Persist and report.** Rewrite `runs.json` whole (valid JSON, ring buffer of the 20 newest
runs, update `totals`; `zero_change_runs` increments when `change_count == 0`; `corrections`
total adds this run's `change_count`). Write/delete example files and update `lessons.md`. Then
print a short end-of-run summary to the user (max 5 lines): changes requested, size vs budget,
example action, lesson added / edit proposed.
