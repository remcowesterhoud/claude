# PR Writing Style

When drafting PRs or PR reviews for Remco (`remcowesterhoud`), match the patterns below. Based on analysis of his last 50 authored PRs and ~10 sampled review threads in `camunda/camunda`.

## Canonical Review Emoji Code (from CONTRIBUTING.md)
- 👍 / `:+1:` — "This is great!"
- ❓ / `:question:` — "I have a question. Please clarify."
- ❌ / `:x:` — "This has to change."
- 🔧 / `:wrench:` — "Well-meant suggestion or minor issue. Take it or leave it."
- 💭 / `:thought_balloon:` — "Thinking out loud, doesn't necessarily have to change."

## PR Titles
- Often (but not always) uses Conventional Commits prefix (`feat:`, `fix:`, `ci:`, `deps:`, `refactor:`). Roughly half his titles omit the prefix and read as plain sentence-case statements (e.g. "Analytics exporter gap detection", "Fix termination of children when modifying an ad-hoc sub-process").
- Sentence case, no trailing period, 40–90 chars. Descriptive of *what changed*, not the issue ID.

## PR Description Structure
Always uses the repo's PR template. Keep the headings `## Description`, `## Checklist`, `## Related issues`. Leave the HTML comments in place.
- **Description**: 1–4 short paragraphs of plain prose. Opens with what the PR does, then *why* / context. For non-trivial work he adds a second paragraph explaining problems hit and how he solved them. Uses numbered lists (`1.`, `2.`) when enumerating challenges or sub-changes. Embeds screenshots via `<img ...>` and YAML/Java code fences when behavior depends on config.
- **Checklist**: leave the template checkboxes unchecked.
- **Related issues**: `closes #1234`, `Relates to #1234`, or `N/A`. Frequently leaves a trailing space after the number. Uses `closes #` (no number) when there's no issue.
- Trivial PRs (renovate, one-liners) get a single-sentence body, sometimes no template (e.g. "Renovate bump spring core").

## Voice & Tone
- First-person, conversational, lightly self-deprecating. Example openers: "It always bothered me that…", "This turned out to be a bit more troublesome than I had anticipated."
- Explains tradeoffs explicitly: "I solved both of these by…", "I had to add a try-catch on… By simply catching this error…"
- Comfortable with contractions ("it's", "don't", "we're") and casual connectors ("tbh", "atm", "gonna").
- Honest about AI assistance: "I had Claude do this. I've imported the dashboard … and it looks good to me."

## Review Comment Style
- **Leads with the emoji code** to signal intent: `❌`, `❓`, `🔧`, `💭`, `👍`. Often the emoji is the literal first character.
- Uses `🙃` as a personal extra for "nitpicky / silly" suggestions — not in the canonical code but recurring (e.g. "🙃 Bit nitpicky, but…", "🙃 Nitpick. My pea brain cannot stop reading logger as an slf4j logger."). Treat this as a Remco-ism.
- Suggestions: prefers GitHub ```suggestion blocks, followed by a one-line rationale starting with `🔧` or `🙃`.
- Questions are direct: "❓ How can this happen? Why would initialize be called twice?", "❓ Did we forget to add this in the previous PR?"
- "WDYT?" / "wdyt?" is a recurring sign-off when proposing alternatives. Tags people with `@handle` when asking for input.
- Acknowledges learning: "TIL", "Actually had to look this up". Apologetic when asking for rework: "Sorry for the additional work 🙇."
- Approval bodies are usually empty; when not, they're short: "Nice 👍", "Thanks! Nice work 🚀", or pre-approval pattern: "@user I'll pre-approve, but please have a look at my comments before merging."
- Length: most inline comments are 1–3 sentences. Goes longer (full paragraph + reasoning) only when proposing an architectural alternative.

## What He Does NOT Do
- No "LGTM" throwaway approvals — empty-body approval instead.
- Does not use 🎉, ✨, ✅ or generic decorative emoji in PR bodies. Reactions stay within the emoji code + 🙃, 😄, 🙇, 🚀, 🤔.
- Does not fill out the template checklist boxes.
- Does not write a separate "Test plan" section — testing is mentioned inline in the Description if relevant.
- Does not pad descriptions; if a PR is trivial, the body is one sentence.
- **Does not overwhelm PRs with nitpicks.** Nitpicks (🙃) are personal preference, not requirements — keep them sparse. If a PR has many small style issues, pick the few that matter most rather than commenting on every one. 🔧 "take it or leave it" suggestions are *not* nitpicks and remain worth raising as usual.

## How to apply
When asked to draft a PR or a review comment for Remco, produce text that follows these patterns by default — don't add Test Plan sections, don't tick the template checklist, don't sprinkle decorative emoji, and lead review comments with the appropriate emoji-code character. When unsure about tone, lean conversational and first-person.
