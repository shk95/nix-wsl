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

### `cat: /proc/sys/fs/binfmt_misc/WSLInterop: No such file or directory`

Equivalently, and how you will actually meet it: every Windows executable stops
working from Linux, with

```
fork/exec /mnt/c/WINDOWS/system32/cmd.exe: exec format error
```

`/mnt/c` still reads fine, which is what makes it confusing — drvfs is healthy,
it is *interop* that is gone. Anything shelling out to `cmd.exe`, `powershell`,
`wsl.exe`, `explorer.exe`, `clip.exe` or `code` fails; on Ubuntu the loudest
symptom is `wsl-pro.service` restart-looping in the journal every twenty
minutes.

**Do not go looking in the Nix configuration or the login shell.** Neither can
reach `binfmt_misc`: it is a kernel-global registry, and a home-manager
generation or a `chsh` cannot write to it. This was mis-attributed to both for a
day.

**What is actually wrong.** Interop is one `binfmt_misc` registration:

```
$ cat /proc/sys/fs/binfmt_misc/WSLInterop
enabled
interpreter /init
flags: P
offset 0
magic 4d5a                                  # "MZ", the DOS/PE header
```

When it is missing, the kernel has no handler for a PE binary and `execve`
returns `ENOEXEC` — which is precisely `exec format error`.

**All WSL distributions share one `binfmt_misc` registry**, the same way they
share one cgroup hierarchy (see the entry below). It is global state that no
distribution owns and any distribution can empty. Check whether it was emptied
rather than merely damaged:

```
$ ls /proc/sys/fs/binfmt_misc/
register  status                            # nothing else — the whole registry is gone
$ cat /proc/sys/fs/binfmt_misc/status
enabled
```

There are two different ways entries disappear, they have different causes, and
guessing between them wastes the afternoon. `systemd-binfmt` is the program to
read — `src/binfmt/binfmt.c` and `src/shared/binfmt-util.c`:

| | what it does | when |
| --- | --- | --- |
| `apply_rule()` | for each rule in `binfmt.d`, writes `-1` to `.../binfmt_misc/<name>` — a delete **by name** — and then registers its own | every `ExecStart` |
| `disable_binfmt()` | writes `-1` to `.../binfmt_misc/status` — flushes **every** entry | only `--unregister`, i.e. `ExecStop` |

So a `binfmt.d` rule named `WSLInterop` in *any* distribution does not add to
the shared registry. It **deletes whatever is there and substitutes its own**.
That is what WSL means by "overriding", and it is a takeover, not a merge.

Tell the two apart by mtime, which survives when nothing else does:

```
$ stat -c '%n %y' /proc/sys/fs/binfmt_misc/register /proc/sys/fs/binfmt_misc/status
register  2026-08-05 15:38:38     ← last registration
status    2026-08-04 00:31:19     ← mount time; never written = never flushed
```

If `status` still carries the boot-time timestamp, no `--unregister` has ever
run and you are looking at a by-name takeover, not a flush.

Ubuntu is protected against its own copy of that unit and nobody else's. WSL
generates the guard, which is worth reading because it documents the whole
problem:

```
$ cat /run/systemd/generator/systemd-binfmt.service.d/override.conf
# Note: This file is generated by WSL to prevent binfmt.d from overriding WSL's binfmt interpreter.
# To disable this unit, add the following to /etc/wsl.conf:
# [boot]
# protectBinfmt=false

[Service]
ExecStop=
ExecStart=/bin/sh -c '(echo -1 > /proc/sys/fs/binfmt_misc/WSLInterop) ; (echo ":WSLInterop:M::MZ::/init:P" > /proc/sys/fs/binfmt_misc/register)'
```

`ExecStop=` disarms the flush and the appended `ExecStart` puts the entry back
after `binfmt.d` has been applied. A drop-in in one distro cannot guard a
registry shared with the others.

**Getting it back, now.** No reboot needed, but it is root-only:

```sh
echo ':WSLInterop:M::MZ::/init:P' | sudo tee /proc/sys/fs/binfmt_misc/register
```

`wsl --shutdown` from Windows also fixes it — WSL re-registers at boot — but you
cannot run that from inside, because `wsl.exe` is itself an `.exe`.

**It is the second distribution's *shutdown* that does it, and no amount of
NixOS configuration prevents it.** Measured on 2026-08-05 by watching the
registry from Ubuntu at each step:

| step | registry seen from Ubuntu |
| --- | --- |
| baseline | `WSLInterop`, `interpreter /init` |
| `wsl -d NixOS` — booted, left running | `WSLInterop`, `interpreter /init` — **unharmed** |
| exit the NixOS shell (distro shuts down) | **gone** |

Booting the second distribution is harmless. Note that it is harmless even
though `systemd-binfmt` ran inside it and its `binfmt.d` rule names
`WSLInterop`: WSL's generated drop-in re-registers `:WSLInterop:M::MZ::/init:P`
as a second `ExecStart`, which lands after the NixOS rule and puts the original
line back. The interpreter reads `/init`, not `/run/binfmt/WSLInterop`, which is
how you can tell.

**The shutdown flushes the whole registry, and it is PID 1 that does it.** Not
`systemd-binfmt.service` — `systemd-shutdown`, the binary systemd becomes at the
end of shutdown:

```c
/* systemd/src/shutdown/shutdown.c */
        disable_coredumps();
        (void) disable_binfmt();                        /* -1 into .../binfmt_misc/status */

        log_info("Sending SIGTERM to remaining processes...");
```

`disable_binfmt()` has exactly two callers in the whole tree — `binfmt.c` under
`--unregister`, and this one. This one is unconditional. There is no unit, no
`ExecStop`, no drop-in and no configuration option anywhere in its path, and the
journal line right after it is the one you can see in every WSL distro shutdown:

```
systemd-shutdown[1]: Sending SIGTERM to remaining processes...
```

So **any** systemd distribution shutting down empties the registry for every
distribution still running. This is why unrelated entries vanish together, and
it is the answer to `python3.14`.

**Do not try to prove a flush from `status`'s mtime.** binfmt_misc does not
update it on write — it still reads as the mount time on a host where flushes
have demonstrably happened. `register`'s mtime *does* move. An afternoon was
lost to that asymmetry.

The reliable test is a canary: register a second entry under a name nothing else
knows, then look for it.

```sh
echo ':CanaryZZ:M::MZ::/init:P' | sudo tee /proc/sys/fs/binfmt_misc/register
```

If `CanaryZZ` is gone, it was a flush — nothing deletes that name by name.

**Fixed for this repository's NixOS flavour, on 2026-08-05.** The guest cannot
stop `systemd-shutdown` calling the flush, but it can make the call decline.
`disable_binfmt()` opens with `binfmt_mounted_and_writable()`, which ends in
`access_fd(fd, W_OK)` — so a distribution whose *own* view of the registry is
read-only skips it. `modules/wsl.nix` declares that as
`systemd.services.wsl-binfmt-protect`:

```sh
mount --make-private /proc/sys/fs/binfmt_misc     # do not propagate back to the other distro
mount -o remount,bind,ro /proc/sys/fs/binfmt_misc # bind: this mount only, not the shared superblock
```

The `bind` is not decoration. Without it the read-only lands on the superblock,
which every distribution shares, and Ubuntu — the one that still needs to
write — loses the registry instead. Check with `grep binfmt_misc /proc/mounts`
on both sides: the guest should say `ro`, Ubuntu `rw`.

The guest loses nothing: read-only blocks writing the registry, not reading or
matching it, and WSL's entry names `/init` with `P` and no `F`, resolved at exec
time in the caller's own namespace. `.exe` keeps working in both.

**If you are on a distribution this repository does not manage**, the fallback
is unchanged: run one at a time, and re-register by hand with the command above.

**How to attribute it, if it happens again.** The registry keeps no history, so
the journal is all there is. Interop's last known-good moment and the first
`exec format error` bracket it, and every distro start and stop is logged:

```sh
journalctl | grep -n "exec format error" | head -1
journalctl --since "<that time minus an hour>" | grep -E "WSL \(|systemd-binfmt"
```

`WSL (2 - init-systemd(NixOS))` in that window is a second distribution booting,
and is the thing to suspect first.

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
