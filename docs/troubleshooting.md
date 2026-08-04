# Things that already cost someone an afternoon

Findings that recur. Not a changelog and not a diary — `docs/status.md` holds the
current state and the decisions, this holds the things that will bite again.

**Search this file by the error text, not by reading it.** Headings are the
literal message you will see, so `grep` finds the entry that matches what is in
front of you.

**Bar for adding an entry:** it cost more than a quarter of an hour to work out,
*and* it will happen again — to a future session, on another machine, or after a
dependency upgrade. A typo you fixed in a minute does not belong here. Keep
entries to a few lines; a long one means the explanation belongs in a code
comment where the problem lives.

---

## Nix

### `A corresponding Nix package must be specified via 'nix.package' for generating nix.conf.`

Standalone home-manager (no NixOS or nix-darwin underneath) cannot infer which
Nix binary should generate `nix.conf` the way the OS-level modules can. Set
`nix.package = pkgs.nix;` in whichever module sets `nix.settings` — here that is
`home/nix.nix`. Only `homeConfigurations` needs this.

Note that `nix flake check` passes with this bug present; see the entry below.

### `nix flake check` passes but the configuration is broken

`nix flake check` validates the flake's shape and its standard outputs. It does
not descend into `homeConfigurations` or `nixosConfigurations` — those are
arbitrary attributes as far as it is concerned. Forcing the toplevel derivation
is what actually evaluates them:

```sh
nix eval --raw '.#homeConfigurations."<name>".activationPackage.drvPath'
nix eval --raw '.#nixosConfigurations."<name>".config.system.build.toplevel.drvPath'
```

`tool/checks/test` does this for every configuration.

### `Path 'flake.nix' in the repository "..." is not tracked by Git`

Flakes only see files known to git — an untracked file is invisible to flake
purity even when it is sitting right next to a tracked one. Before the first
`nix flake check` / `nix build` on brand-new files:

```sh
git add -N <the new files>
```

`-N` (intent-to-add) is enough; a full `git add` is not required yet. Name the
paths rather than running `git add -N .` — it fails outright the moment the
tree contains anything that is not a regular file or symlink, and the whole
command aborts instead of adding the files you actually meant.

### `experimental Nix feature 'nix-command' is disabled`

There is no `~/.config/nix/nix.conf` yet, which is the state of any machine
before its first `home-manager switch` — `home/nix.nix` is what writes it.
Export `NIX_CONFIG="experimental-features = nix-command flakes"` for the
session rather than writing the file by hand: home-manager refuses to clobber
an unmanaged file, so hand-writing it turns the first switch into a failure.

This host passed that point on 2026-08-03 and no longer needs the variable. The
entry stays because a fresh clone on a new machine starts where this one did.

Note that `nix config show` cannot diagnose this — it needs `nix-command` in
order to run at all. `tool/doctor.sh` probes with `nix flake metadata` instead,
which exercises both flags the way real commands do.

### GitHub Actions never runs, and every API check says it is enabled

A new repository can have Actions switched off in a way nothing visible
reports. Everything that looks like a diagnostic lies:

```
$ gh api repos/<owner>/<repo>/actions/permissions
{"enabled":true,"allowed_actions":"all","sha_pinning_required":false}
$ gh api repos/<owner>/<repo>/actions/workflows -q '.workflows[].state'
active
```

Both were byte-identical to a repository where Actions worked. The only
signal is negative — `gh api repos/<owner>/<repo>/actions/runs -q .total_count`
stays at `0` no matter what you push. Fix it in **Settings → Actions** in the
web UI.

Two consequences worth knowing before you go looking:

- **Enabling does not replay missed events.** Pushes and pull requests that
  happened while it was off are gone; you need a fresh event. Pushing to an
  open pull request's head branch is the cheapest one, since it fires
  `pull_request: synchronize` even when the branch itself is not in the
  workflow's `push` filter.
- **It interacts badly with branch protection.** `setup-repo.sh` makes the
  release branch require the `Secret scan` check. With Actions off that check
  never reports, so every pull request into it waits forever on something that
  cannot arrive — and the branch protection settings look perfectly correct
  while it happens.

### `tool/doctor.sh`: `could not ask the flake whether nix-command works`

The doctor could not run `nix flake metadata`, and the failure was *not* the
experimental-features flag — so exporting `NIX_CONFIG` will not clear it. The
rest of the line is the root cause nix reported; act on that.

Seen so far: a read-only `~/.cache/nix` (agent sandboxes deny it), no network,
and an untracked `flake.nix`. Each of these used to be reported as
"nix-command/flakes not enabled by default", which sent you to a variable that
could not help.

### `wsl: Failed to start the systemd user session for '<user>'.`

Printed on entering a second WSL distribution. It is **not** a bug in that
distribution, and chasing it there wastes the afternoon. In the journal:

```
systemd[1]: user@1000.service: Failed to spawn executor: Device or resource busy
systemd[1]: user@1000.service: Failed with result 'resources'.
```

**All WSL distributions share one cgroup v2 hierarchy.** Confirmed rather than
inferred — `/sys/fs/cgroup` reports the same `st_dev` from both distros, and
from inside the failing one you can see the *other* distro's delegated subtree,
already populated:

```
$ cat /proc/387/cgroup                     # Ubuntu's systemd --user
0::/user.slice/user-1000.slice/user@1000.service/init.scope
# and from inside NixOS, the same path:
  session.slice  init.scope   ← 3 processes, none of them ours
```

So two distributions whose default user is UID 1000 both want
`/user.slice/user-1000.slice/user@1000.service`. Whichever booted first owns it;
the second gets `EBUSY`. The control experiment settles it — in the failing
distro, a UID nobody else has claimed starts fine:

```
user@0.service    (UID 0,    unclaimed)      → active
user@1000.service (UID 1000, held by Ubuntu) → failed
```

**What it costs.** System units are unaffected; `systemctl is-system-running`
reports `degraded` only because of this and `getty@tty1`, which has no tty in
WSL and always fails. What breaks is the *user* level: no user D-Bus socket, so
`systemctl --user` is unusable and any home-manager systemd user service will
not start.

**What to do.** Give the second distribution's user a different UID
(`users.users.<name>.uid`), so the paths do not collide; or run only one of them
at a time; or wait for WSL to isolate per-distro cgroups —
[microsoft/WSL#40519](https://github.com/microsoft/WSL/pull/40519), not present
in WSL 2.7.11.0. The UID workaround is untested here.

### `wsl --import` will not read the image from `\\wsl.localhost\...`

The obvious way to import a rootfs built inside WSL is to point at it where it
already is:

```
wsl --import NixOS C:\WSL\NixOS \\wsl.localhost\Ubuntu-26.04\home\<user>\...\nixos.wsl
```

It does not work, and the interesting part is that the path is fine. `dir` reads
it through both spellings:

```
> dir \\wsl.localhost\Ubuntu-26.04\home\user1\github_prj\nix-wsl\nixos.wsl
       603,474,420 nixos.wsl
> dir \\wsl$\Ubuntu-26.04\home\user1\github_prj\nix-wsl\nixos.wsl
       603,474,420 nixos.wsl
```

So it is not permissions, not 9p, and not the distro name. The importer
specifically does not accept a UNC source. Copy the image to a real Windows
drive first and give it a plain path — `just nixos-stage` does that, verifies
the copy, and prints the exact command. It takes about four seconds over drvfs.

### CI fails on a path that exists on your machine

```
error: path '«git+file://…?ref=…&rev=…»/home/programs/<file>.nix' does not exist
```

The file is `git add`-ed but never committed. A flake reads the *working tree*
of a dirty repository, so `tool/checks/test` — and therefore the `pre-push`
hook — sees it and passes. CI checks out the commit, where only the *reference*
to it landed. `git status` shows it as `A ` rather than untracked, which is easy
to read past.

A file that is untracked entirely does not do this: flakes refuse to see it and
the local build fails first, with `Path '…' is not tracked by Git` above.

```sh
git log --stat -1          # what actually went into the commit
git diff --cached --stat   # what is still only staged
```

### `git push` fails with the same `nix-command is disabled` message

Not a git problem, and nothing in the output says a hook ran. `pre-push`
invokes `tool/checks/test`, which is a Nix command, so on a host where flakes
are not enabled globally the push dies with a Nix error. Export `NIX_CONFIG` in
the shell you push from. `--no-verify` also gets the push through, but skips
the tests, which is the thing the hook is for.

### statix: `Found empty pattern in function argument`

A module written as `{...}: { ... }` when nothing from the module arguments is
used. statix wants `_: { ... }` instead — identical behaviour, but it does not
read as attrset-destructuring for a value that is never destructured. Modules
that do use some arguments (`{pkgs, ...}: ...`) are unaffected.

### deadnix reports unused code but the lint check still passes

deadnix's default exit code is 0 regardless of findings. `tool/checks/lint`
passes `--fail`; without it the check is cosmetic.

### `evaluation warning: The default value of 'programs.X.Y' has changed ... because 'home.stateVersion' is less than "..."`

Cosmetic, but recurs on every build until addressed. Either pin the option
explicitly (keeps the old behaviour, silences the warning) or bump
`stateVersion` deliberately after reading the home-manager release notes for
what else changes with it — pinning is the lower-risk fix in the middle of
unrelated work.

### Korean renders as boxes in the terminal, and declaring a font changes nothing

Because the terminal's font is not a Linux setting. Windows Terminal draws with
a font named in its own `settings.json` and reads it from Windows — a font in
the Nix store is invisible to it, so `home/fonts.nix` cannot fix this and adding
a Nerd Font there would only spend 194 MiB proving it.

The fix is on the Windows side, in the profile's font, as a fallback list:

```json
"font": { "face": "Cascadia Mono, Malgun Gothic" }
```

`settings.json` is at
`%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`.
The second name is what covers Hangul when the first does not; without a
fallback the terminal substitutes per-glyph and the row's metrics stop lining up,
which is the misalignment that usually gets described as breakage rather than
the boxes themselves.

**Check which side you are actually on.** If GUI applications under WSLg render
Korean and the terminal does not, it is the terminal, and nothing in this
repository is involved:

```sh
fc-match 'sans-serif:lang=ko'      # what Linux resolves Korean to
```

That command answering `Noto Sans CJK JP` is not the bug — see the comment in
`home/fonts.nix` for why the family name says JP while the coverage is Korean.

Nothing answering at all is a real gap, and it is the NixOS-WSL case:
`fonts.enableDefaultPackages` is `false` and `fonts.packages` is empty there, so
that flavour has no font of any kind until one is declared.

---

## The agent sandbox

Everything here has one cause: an agent's shell tool runs inside a mount
namespace that bind-mounts over the paths it is not allowed to touch. What the
agent sees is real *inside that namespace* and absent everywhere else, so these
symptoms cannot be reproduced by a person in a terminal — which is exactly why
they waste time.

**The test that settles all of them is the same:** run the command again
outside the sandbox and compare. If the two disagree, the sandbox is the
subject, not the repository.

### `error: <file>: can only add regular files, symbolic links or git-directories`

Followed by `fatal: adding files failed`, and usually met while running
`git add -N .` before a flake build (see *`Path 'flake.nix' ... is not tracked
by Git`* above).

The named file is a bind-mounted `/dev/null`, not anything on disk. `ls -l`
gives it away:

```
crw-rw-rw- 1 nobody nogroup 1, 3 .bashrc
```

`c` for character device, `1, 3` being `/dev/null`, `nobody nogroup` being the
user namespace showing through. Whole families of them appear at once, sharing
one mtime to the nanosecond. Nothing was created in the repository and there is
nothing to clean up.

### `git status` lists dotfiles nobody put there

`.bashrc`, `.zshrc`, `.zprofile`, `.gitconfig`, `.idea`, `.vscode`, `.mcp.json`
and similar, all untracked, in a repository that has never contained them. Same
cause as the entry above: the agent's deny-list is mostly named after home
directory and editor files, and each denied path that does not exist becomes a
device node inside the namespace.

`git status` **exits 0 here.** It is not failing; it is answering truthfully
about a filesystem that only it can see. That is what makes this worse than a
probe that errors — see *A green `git status` described a filesystem nobody
had* in `docs/status.md`.

### `warning: unable to access '<repo>/.gitmodules': Permission denied`

Emitted by git commands that otherwise succeed — `git fetch` and `git status`
print it and then work correctly. The path is read-only inside the namespace.
Harmless, and not a sign of a damaged repository or a permissions problem in
`$HOME`.
