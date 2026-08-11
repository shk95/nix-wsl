# Contributing

This is the shared workflow for people and tools. The model-independent agent
judgement contract lives in `AGENTS.md`; user-facing setup and usage live in
`README.md`. A person can follow this document without reading an agent file.

## Prepare a clone

Git does not clone repository-local configuration. The hook scripts are tracked
under `.githooks/`, but a clone will not run them until `core.hooksPath` is set.

Inspect the change first, then apply it explicitly:

```sh
tool/setup
tool/setup --fix
tool/doctor.sh
```

`tool/setup` changes nothing without `--fix`. `tool/doctor.sh` is always
read-only and reports whether this host can build, check and commit the project.
If a command runs inside an isolated environment, a failure caused by denied
access to host caches is not evidence that the host itself is broken; compare
with an authorised host-side run before changing configuration.

Hooks are deliberately not the final authority. They can be bypassed with
`--no-verify`, and the local secret scan is skipped when `gitleaks` is absent.
CI repeats the required checks in a clean clone and scans repository history.

## Local state boundary

Do not encode a snapshot of one machine as repository truth. The relevant
state has different owners:

| State | Owner and check |
| --- | --- |
| Hook scripts | Tracked in `.githooks/` |
| Hook activation | Clone-local `.git/config`; inspect with `tool/setup` |
| Git identity and GitHub authentication | User-local; reported by `tool/doctor.sh` |
| Nix features, tools and build access | Host-local; probed by `tool/doctor.sh` |
| home-manager activation and login shell | Host-local external state; never inferred from committed prose |
| Model permissions and credentials | Tool-local; local overrides stay ignored and are not project policy |

The repository may document how to inspect or establish these states, but a
dated claim that they are currently true is not a substitute for observation.
Setup helpers must not silently modify user-global configuration.

## Start work

The branch flow is:

```text
master (released) <- dev (integration) <- feature/<name> or fix/<name>
```

`dev` is the default branch. Branch from it and merge back to it. Never commit
directly to `master`.

1. Run `tool/doctor.sh` and understand every failure or warning relevant to the
   task.
2. Run `tool/worktree.sh list` before assuming a shared resource is available.
3. Check `gh issue list --label blocked` for work this host may now be able to
   verify.
4. Read the relevant part of `docs/status.md`; do not load historical material
   that has no bearing on the task.
5. Create a worktree with `tool/worktree.sh new <name> feature` (or `fix`), or
   create the equivalent branch from `dev` when working in place.

Worktrees share the repository's Git configuration, including `core.hooksPath`.
They do not make host-global resources safe to use concurrently. Activation and
anything writing to a fixed path under `$HOME` must be serialised.

## Verify work

The common checks are:

```sh
tool/checks/format
tool/checks/lint
tool/checks/test
```

`tool/checks/test` builds rather than activates. Use the more specific runtime
or hardware checks in `docs/definition-of-done.md` when the change requires
them. Do not mark an item verified unless it was observed on a suitable host.
Activation is not routine verification: it changes files outside the repository
and must be a deliberate, separately requested operation.

When this host cannot perform a required check, open an issue rather than
silently dropping it:

```sh
gh issue create --label blocked --label blocked/<reason> \
  --title "<milestone>: <what still needs checking>" \
  --body "<what changed, what was tested, and how to close this gap>"
```

## Record the result

Put information where its audience and lifetime match:

| Location | Responsibility |
| --- | --- |
| `README.md` | What the project is, setup and everyday use |
| `CONTRIBUTING.md` | The shared contribution workflow |
| `AGENTS.md` | Stable judgement, trade-offs and safety boundaries |
| `docs/status.md` | Current state and decisions expensive to reverse |
| `docs/troubleshooting.md` | Recurring failures, indexed by literal symptom |
| `tool/`, `.githooks/`, CI | Rules that can be executed instead of narrated |

Record the reasoning for decisions that are expensive to reverse. Record a
troubleshooting entry when a recurring problem took meaningful time to solve.
Do not turn either document into a chronological activity log.

## Finish work

1. Walk through the "Every change" list and the relevant milestone in
   `docs/definition-of-done.md`.
2. Record decisions, recurring findings and anything still unverified in the
   locations above.
3. Run the format, lint and test checks.
4. Commit by concern using Conventional Commits. Keep the subject at 72
   characters or fewer; explain why in the body when the diff is not enough.
5. Push the branch and open a pull request into `dev`. Include the verification
   evidence and links to blocked issues for anything not verified.

All repository text is English because the repository is public.
