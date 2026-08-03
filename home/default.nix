{user, ...}: {
  imports = [
    ./nix.nix
    ./packages.nix
    ./shell.nix
    ./starship.nix
    ./programs
  ];

  home = {
    username = user;
    homeDirectory = "/home/${user}";

    # Bump only after reading the home-manager release notes for breaking changes.
    stateVersion = "25.05";
  };

  # let home-manager manage its own package so `home-manager` stays on PATH
  programs.home-manager.enable = true;
}
