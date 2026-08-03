---
description: Verify against the definition of done, record what is unfinished, and open a pull request
---

Close out the current branch honestly. The point of this command is that
"it compiles" is not the finish line — and that anything you could not verify
gets written down rather than quietly dropped.

1. **Check against the definition of done.** Open
   `docs/definition-of-done.md`, take the "Every change" list plus the section
   for this milestone, and go through it item by item. For each, say which of
   these it is:
   - verified, and how
   - not applicable, and why
   - **not verifiable on this host** — which needs an issue, below

   Do not tick an item you have not actually observed. A test that was written
   but never run against real hardware is not a verified device scenario.

2. **File the gaps.** For everything in the third category, open an issue:

   ```sh
   gh issue create --label blocked --label blocked/<what-is-missing> \
     --title "<milestone>: <what still needs checking>" \
     --body "<what was built, what was tested, and the steps to close this>"
   ```

   Always two labels: `blocked` — the umbrella that `gh issue list --label
   blocked` finds, since GitHub matches labels exactly — plus one saying what is
   missing. Write the body for a session that has none of your context: say what
   to do, not just what is missing.

3. **Update the records.**
   - `docs/status.md` — only if a decision was made that is expensive to
     reverse; record the reasoning, not just the conclusion
   - `README.md` — the milestone table, if its state changed
   - `docs/troubleshooting.md` — if something cost you more than a quarter of an
     hour to work out *and* would cost the next session the same. Heading is the
     literal error text so it can be found by grep; three or four lines of
     symptom, cause and fix. Skip anything you solved in a minute — a file full
     of trivia is one nobody greps.

4. **Verify.** Run the format, lint and test checks under `tool/checks/`.
   Regenerate and commit any generated code.

5. **Commit and push.** Conventional Commits, split by concern rather than one
   large commit. Bodies say *why*, since the diff already says what.

6. **Open the pull request into the integration branch** — never into the
   release branch:

   ```sh
   gh pr create --base dev --title "<conventional commit style>" --body "..."
   ```

   The body must contain the definition-of-done walkthrough from step 1,
   including the items that were **not** verified and links to the issues filed
   for them. A reviewer should be able to see what is unproven without reading
   the code.
