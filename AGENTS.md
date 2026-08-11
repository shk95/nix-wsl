# Repository guidance for agents

This file is the model-independent source of repository guidance. Product-
specific files may point here or configure permissions, but must not restate
project policy.

## What to optimise for

- **The durable output is the finding, not the configuration.** This repository
  is a Nix testbed. Preserve reasoning that will matter after the current
  configuration is rewritten: failed approaches, expensive decisions and
  recurring failure modes.
- **Keep both flavours first-class.** Standalone home-manager is not a staging
  ground for NixOS-WSL. Prefer `modules.homeManager.shared` when a feature can
  work in both. Moving a package or option into the system layer must justify
  why losing it from standalone is the right trade.
- **Prefer reproducibility to host convenience.** `flake.lock` is the pin. An
  input update is a deliberate change, not routine cleanup. Do not hide host
  assumptions in an otherwise reproducible check.
- **Optimise for honest evidence.** A build proves evaluation and construction;
  it does not prove activation or runtime behaviour. Say what was observed,
  distinguish it from inference, and leave unverifiable work explicit.
- **Keep the scope at WSL on `x86_64-linux`.** Supporting another system changes
  what this host and CI can honestly verify and therefore requires an explicit
  scope decision.

## Boundaries that protect the host

- Never activate a configuration without an explicit request. Commands such as
  `home-manager switch` write outside the repository and can partially replace
  a working environment. Build with `tool/checks/test` for routine verification.
- Do not update flake inputs, garbage-collect the Nix store, change the login
  shell, or alter Git/global user configuration unless the task calls for that
  external state change.
- Treat WSL kernel-global resources as unowned shared state. Before changing
  cgroups, `binfmt_misc`, mounts or similar facilities, ask what happens to the
  other distributions at startup and shutdown. The damage may appear somewhere
  other than where the change was made.
- If an isolated execution environment reports repository or host state that
  contradicts the disk or a person-operated shell, test the isolation boundary
  before treating the report as real. Do not silently work around denied access.

## Working contract

1. Run `tool/doctor.sh` before relying on host-local capabilities. It diagnoses;
   it does not repair. `tool/setup --fix` is the explicit operation for applying
   this clone's repository-local Git settings.
2. Follow `CONTRIBUTING.md` for branches, commits, checks, pull requests and the
   definition of done. Do not duplicate that workflow in model-specific files.
3. Use `docs/status.md` for current state and costly decisions. Search
   `docs/troubleshooting.md` by concrete symptom rather than loading it as
   general context.
4. Verify changes with the scripts under `tool/checks/`. Git hooks are useful
   local feedback, not proof: their activation is clone-local, they can be
   bypassed, and optional tools may be absent. CI is the clean-clone backstop.
5. Record expensive reasoning, not routine activity. Update `docs/status.md`
   when a decision is costly to reverse; add troubleshooting only for a
   recurring problem that took meaningful time to resolve.

Committed prose is not authoritative about the current host. Re-observe local
Git, authentication, Nix and activation state when it matters to the task.

Everything committed to this public repository—documentation, code comments,
commit messages, issues and pull requests—is written in English.
