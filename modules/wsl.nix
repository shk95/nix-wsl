{config, ...}: let
  inherit (config.identity) user;
in {
  modules.nixos.wsl = {
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

    # Deliberately almost empty. The experiment is whether a system layer earns
    # its place, and starting it with packages and services already moved in
    # would answer that question by assumption. What belongs here is what
    # standalone home-manager genuinely cannot declare — and note that moving a
    # package here does not "share" it, it *removes* it from the standalone
    # flavour, which has no `environment.systemPackages` at all.
  };
}
