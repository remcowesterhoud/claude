# Maven Output Filtering

Don't pipe full Maven output into context. Filter to just what's needed: BUILD result, failing tests, error messages.

**Why:** Maven is extremely verbose (dependency resolution, plugin banners, download progress, repeated INFO lines). Dumping the full output burns tokens for no real signal.

**How to apply:**
- Default to `-q` (quiet) on `./mvnw` invocations to suppress INFO chatter while keeping warnings/errors.
- Add `--batch-mode` to drop download progress bars.
- For tests, add `-Dsurefire.useFile=false` and pipe through `grep -E 'BUILD|ERROR|FAIL|Tests run'` or `tail -n 50` when only the summary matters.
- Only fall back to full unfiltered output when actively debugging a build that fails in a way the filtered view doesn't surface.
