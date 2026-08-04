# Standalone only: this writes ~/.config/nix/nix.conf, which is what makes flakes
# work on a host where Nix came from the plain upstream installer and nothing
# system-wide enabled them. Under NixOS the same settings are a system concern and
# come from elsewhere entirely.
#
# The file it generates is also the reason the first activation on a fresh machine
# is delicate: home-manager refuses to clobber an unmanaged
# ~/.config/nix/nix.conf, so hand-writing one to get flakes working turns the
# first switch into a failure. Export NIX_CONFIG for that shell instead.
_: {
  modules.homeManager.standalone = {pkgs, ...}: {
    nix = {
      package = pkgs.nix;
      settings.experimental-features = ["nix-command" "flakes"];
    };
  };
}
