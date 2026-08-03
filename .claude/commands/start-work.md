---
description: Orient in the project, pick the next task, and branch for it
---

Work out what to do next here, and set up to do it. Do not start writing code
until the final step.

1. **Check the machine.** Run `tool/doctor.sh`. If it exits non-zero, stop and
   report what is missing — everything below assumes a working toolchain, and a
   clone with no git hooks commits without a secret scan.

2. **Check what is already in flight.** Run `tool/worktree.sh list`. If another
   session holds a worktree, do not pick work that needs the same shared
   resource — a connected device, a running instance of the app, anything
   writing to one fixed path.

3. **Check what was left unfinished.** Run `gh issue list --label blocked`.
   These are things a previous session wrote but could not verify because it
   lacked a device or a platform. For each, judge whether *this* host can now
   verify it. Anything newly unblockable takes priority over new work — it is
   already written and only needs confirming.

4. **Read the state.** `docs/status.md` for where the project stands and which
   decisions are expensive to reverse. `README.md` for the milestone table.

5. **Propose the work.** Name one task and say why it is the right one now:
   what it unblocks, and what it depends on. If the obvious next milestone
   cannot be verified on this host, say so and propose the best alternative
   rather than starting something that cannot be finished.

   Wait for the user to agree before continuing.

6. **Branch.** From the integration branch, never from the release branch:

   ```sh
   tool/worktree.sh new <short-name> feature   # or fix
   ```

   Work in place instead if the user prefers: `git checkout dev && git pull &&
   git checkout -b feature/<name>`.

Finally, restate the definition of done for this milestone from
`docs/definition-of-done.md`, so the target is explicit before any code exists.
