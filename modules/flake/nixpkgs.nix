# One nixpkgs configuration, declared once and read by both flavours.
#
# This is the structural version of a fix that was already made once by hand.
# `allowUnfree = true` used to be written inline where the standalone flavour
# built its pkgs, and the NixOS flavour builds its own from `nixpkgs.config` —
# so the *shared* home-manager modules were evaluated under two different
# nixpkgs configurations, and nothing said so:
#
#   standalone  true
#   nixos-wsl   false
#
# Deduplicating the value fixed that instance. Declaring it as an option is what
# stops the next one: there is a single name to read, and both places that
# consume it are reachable from here.
{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (lib) mkOption types;
  # Bound here so the `config = …` below reads as nixpkgs' argument rather than
  # as something recursive.
  nixpkgsArgConfig = config.nixpkgsConfig;
in {
  options.nixpkgsConfig = mkOption {
    type = types.attrs;
    default = {};
    description = ''
      The `config` passed to nixpkgs, for every flavour. It is consumed twice and
      both are needed: `pkgs` below is what the standalone flavour evaluates
      against, and `nixpkgs.config` in `flake/configurations.nix` is what the
      NixOS flavour uses — `useGlobalPkgs` makes home-manager take the system's
      pkgs and refuses its own `nixpkgs.*` options outright.
    '';
  };

  config = {
    nixpkgsConfig.allowUnfree = true;

    # flake-parts defaults `pkgs` to `inputs.nixpkgs.legacyPackages`, which
    # carries no config at all. It sets that with `mkOptionDefault`, so replacing
    # it here needs no `mkForce`.
    perSystem = {system, ...}: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = nixpkgsArgConfig;
      };
    };
  };
}
