_: {
  # Everything in here is imported by *both* flavours: the standalone
  # `homeConfigurations.user1` and, through home-manager's NixOS module, by
  # `nixosConfigurations.wsl`. Written once, evaluated twice.
  #
  # Anything that only makes sense without a system layer underneath belongs in
  # `./standalone.nix`, which only the standalone flavour imports — see the
  # comment at the top of that file for what that means and why.
  imports = [
    ./fonts.nix
    ./packages.nix
    ./shell.nix
    ./starship.nix
    ./programs
  ];

  # Needed by both. Bump only after reading the home-manager release notes for
  # breaking changes; it is unrelated to `system.stateVersion` in `../system`,
  # which tracks NixOS's defaults on a different release schedule.
  home.stateVersion = "25.05";
}
