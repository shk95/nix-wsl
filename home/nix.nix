{pkgs, ...}: {
  # standalone home-manager writes this to ~/.config/nix/nix.conf,
  # so it applies even when Nix was installed via the plain upstream installer.
  nix = {
    package = pkgs.nix;
    settings.experimental-features = ["nix-command" "flakes"];
  };
}
