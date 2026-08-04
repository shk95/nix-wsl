{user, ...}: {
  wsl = {
    enable = true;
    # The account WSL logs into. Same unix account as the standalone
    # home-manager configuration, passed through specialArgs from flake.nix so
    # the two cannot drift apart — but note that nothing here manages that
    # account's dotfiles. See system/README-first.md.
    defaultUser = user;
  };

  # A fresh install, so this is the release it was installed with rather than a
  # number copied from home/default.nix. They are unrelated: home.stateVersion
  # tracks home-manager's option defaults, this one tracks NixOS's, and the two
  # projects release on different schedules.
  system.stateVersion = "26.05";

  # Deliberately almost empty. The experiment is whether a system layer earns
  # its place here, and starting it with packages and services already moved in
  # would answer that question by assumption. Anything added here should be
  # something standalone home-manager genuinely cannot declare.
}
