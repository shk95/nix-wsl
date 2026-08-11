{config, ...}: let
  inherit (config.identity) user;
in {
  modules.nixos.wsl = {pkgs, ...}: {
    wsl = {
      enable = true;
      # The account WSL logs into. The same unix account the home-manager
      # fragments configure, read from one declared option so the two cannot
      # drift — but note that nothing here manages that account's dotfiles.
      defaultUser = user;
    };

    # Not 1000, and this is load-bearing rather than taste. Every WSL
    # distribution shares one cgroup v2 hierarchy, so two of them whose users
    # have the same UID both want
    # `/user.slice/user-<uid>.slice/user@<uid>.service` — the second to boot gets
    # EBUSY and its `systemd --user` never starts, which surfaces as WSL's
    # "Failed to start the systemd user session". The Ubuntu side of this machine
    # has this user at 1000.
    #
    # Not 1001 either: that is precisely what Ubuntu's next `useradd` hands out.
    # Its accounts are 1000 and then nixbld at 30001+, so 2000 is clear of both
    # now and of anything either side adds in the near future.
    #
    # Verified inside the running distro before being written, and then verified
    # again by a fresh import: `systemctl --user is-system-running` answers
    # `running`, where UID 1000 could not start the manager at all. See
    # docs/troubleshooting.md under WSL's message.
    users.users.${user}.uid = 2000;

    # The second shared-kernel collision, and the same shape as the UID one
    # above — except this one breaks the *other* distribution rather than this
    # one, which is why it took a day to attribute.
    #
    # Every WSL distribution also shares one `binfmt_misc` registry. WSL's
    # interop — running `.exe` from Linux — is one entry in it,
    # `:WSLInterop:M::MZ::/init:P`, and it is global state no distro owns.
    #
    # **What destroys it is this distro shutting down**, and the cause is inside
    # systemd rather than anywhere configurable:
    #
    #   src/shutdown/shutdown.c:  (void) disable_binfmt();   /* unconditional */
    #
    # `systemd-shutdown` — what systemd *becomes* once every unit is stopped —
    # writes `-1` to `.../binfmt_misc/status`, emptying the registry for every
    # distribution still running. Not a unit. No `ExecStop`, no drop-in, nothing
    # orderable after it. Proven with a canary entry under a name nothing in the
    # system knew: it vanished too, and only a flush can do that.
    #
    # **Two things were tried here first and are not in that path at all** — do
    # not reintroduce them. `wsl.interop.register = true`, so this distro
    # registers its own entry; and `ExecStop = [""]` on systemd-binfmt.service,
    # so its shutdown does not flush. Both build, both were imported and booted
    # on 2026-08-05, and neither changed anything: the first is overwritten
    # within the same service start by WSL's own generated drop-in, and the
    # second disarms `binfmt.c`'s flush while the one that fires is
    # `shutdown.c`'s. See docs/status.md, "The root cause, found by a canary".
    #
    # What is left is the guard `disable_binfmt()` opens with:
    #
    #   r = binfmt_mounted_and_writable();
    #   if (r == 0) { log_debug("... not mounted in read-write mode, not detaching entries."); return 0; }
    #
    # It ends in `access_fd(fd, W_OK)`, so a distribution whose *own* view of
    # `/proc/sys/fs/binfmt_misc` is read-only skips the flush entirely. That is
    # incidentally why agent sandboxes, which bind that path read-only, have
    # never once tripped this.
    #
    # This costs the guest nothing it uses. Read-only blocks *writing* the
    # registry, not reading or matching it, and the entry WSL registers names
    # `/init` with `P` and no `F` — resolved at exec time in the calling
    # process's own namespace. So `.exe` keeps working in here through whichever
    # entry is already registered; only our ability to damage it goes away.
    #
    # **Verified 2026-08-05** by a person, on a freshly imported distro: two
    # boot→shutdown cycles with a canary entry registered in Ubuntu, and a
    # `wsl --unregister` afterwards. Both entries survived all of it, Ubuntu's
    # `/proc/mounts` still said `rw`, and `.exe` kept working throughout. Each
    # of those shutdowns reached `systemd-shutdown[1]: Sending SIGTERM to
    # remaining processes...` — the log line immediately after the
    # `disable_binfmt()` call above — so the flush was attempted and declined,
    # which is the whole claim.
    #
    # It was the third attempt, and the first whose reasoning came from an
    # explicit guard in the source rather than from inference about behaviour.
    # That is the transferable part.
    systemd.services.wsl-binfmt-protect = {
      description = "Make binfmt_misc read-only here so shutdown cannot flush it for other distros";
      wantedBy = ["multi-user.target"];
      path = [pkgs.util-linux];

      # `--make-private` first, so neither the flag change nor anything later
      # propagates back to the distro we are trying to protect. Then
      # `remount,bind,ro`: the `bind` is what confines read-only to *this mount*
      # instead of the superblock, which is shared with every other
      # distribution — without it this would make the registry read-only for
      # Ubuntu too, and Ubuntu is precisely who still needs to write to it.
      script = ''
        mountpoint -q /proc/sys/fs/binfmt_misc || exit 0
        mount --make-private /proc/sys/fs/binfmt_misc
        mount -o remount,bind,ro /proc/sys/fs/binfmt_misc
      '';

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    # Deliberately almost empty. The experiment is whether a system layer earns
    # its place, and starting it with packages and services already moved in
    # would answer that question by assumption. What belongs here is what
    # standalone home-manager genuinely cannot declare — and note that moving a
    # package here does not "share" it, it *removes* it from the standalone
    # flavour, which has no `environment.systemPackages` at all.
  };
}
