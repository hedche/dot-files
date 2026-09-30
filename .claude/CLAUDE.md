# Pull requests

When writing or updating a GitHub PR description:

- Keep the visible body to 20–30 lines. Lead with what changed and why, in 2–4 bullets.
- Include a ```mermaid diagram wherever a flow, sequence, state change, or before/after architecture explains the change faster than prose. Skip it for trivial diffs.
- Put anything long (logs, test output, file-by-file notes, migration steps, screenshots lists) inside `<details><summary>…</summary>` dropdowns. Collapsed content does not count toward the line limit.
- Mirror the repo's PR template headings if one exists; these rules govern how each section is filled.
- State how it was tested and what was not verified. No filler, no restating the diff.
