# Pull requests

When writing or updating a GitHub PR description:

- Keep the visible body to 20–30 lines. Lead with what changed and why, in 2–4 bullets.
- Include a ```mermaid diagram wherever a flow, sequence, state change, or before/after architecture explains the change faster than prose. Skip it for trivial diffs.
- Put anything long (logs, test output, file-by-file notes, migration steps, screenshots lists) inside `<details><summary>…</summary>` dropdowns. Collapsed content does not count toward the line limit.
- Mirror the repo's PR template headings if one exists; these rules govern how each section is filled.
- State how it was tested and what was not verified. No filler, no restating the diff.

# Commands I run myself

When a step needs me to run something (sudo, a password, my machine or my accounts):

- Put the complete command in its own ```bash code block, ready to run as is, so I can press its play button and type my password in the terminal. No placeholders, no `$` prompt, no output inside the block.
- Prefer one line, chaining steps with `&&`, and end with a check whose output proves it worked (e.g. `&& ls -l <file>`). Say in one line what that output should look like.
- Show the block before asking anything about it. Never ask "have you run X?" unless the full command is in a code block in that same message.
- Several commands that must run in order: one block per command, in order, unless they chain safely into one line.

# Questions

Ask every question (decisions, clarifications, "want me to…?" follow-ups) with the AskUserQuestion tool, recommended option first. Never end a reply with questions written as prose.
