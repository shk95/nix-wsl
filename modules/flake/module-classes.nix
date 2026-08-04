# The store every aspect file writes into, and the reason the pattern works at
# all.
#
# Merging is the whole mechanism. Fifteen files each set
# `modules.homeManager.shared`, and `deferredModule` combines them into one module
# that imports all of them — so a feature contributes to a configuration without
# knowing which other features exist, and without anything holding a list of
# them. Declaring the option is what makes that legal: the freeform type guarding
# flake-parts' own `flake` attribute refuses an undeclared attribute defined more
# than once, and says so outright —
#
#   No option has been declared for this flake output attribute, so its
#   definitions can't be merged automatically.
#
# **Not under `flake`, deliberately.** The usual spelling of this is
# `flake.modules.<class>.<name>`, which makes the fragments flake *outputs* — and
# `nix flake check` then prints `warning: unknown flake output 'modules'` on every
# run, including every hook and every CI job. This repository already carries one
# such warning and has it recorded as a cost rather than as noise, so a second
# one is not worth an export nothing consumes. flake-parts has a `touchup` module
# for hiding outputs from `nix flake check`, which is the other way out if these
# ever need to be public; exporting them then is one line:
#
#   flake.homeManagerModules = config.modules.homeManager;
#
# The names under each class are not decoration. They are what
# `flake/configurations.nix` imports, and that file is the single place deciding
# which of them reaches which flavour:
#
#   homeManager.shared      both flavours
#   homeManager.standalone  standalone only — no system layer underneath
#   nixos.wsl               the NixOS flavour only
{lib, ...}: let
  inherit (lib) mapAttrs mkOption types;

  # Mirrors what flake-parts does for its own `flake.nixosModules`. `_class` makes
  # a module used against the wrong evaluator fail by name instead of failing
  # later on a missing option, and `_file` puts this repository in the error
  # rather than an anonymous position in a list.
  #
  # Neither affects output: removing this `apply` entirely was tested against the
  # store-path invariant and changed nothing, so it is here for error messages
  # and costs nothing else.
  classed = class:
    mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = {};
      apply = mapAttrs (name: module: {
        _class = class;
        _file = "modules.${class}.${name}";
        imports = [module];
      });
      description = "${class} module fragments, merged from every file that defines one.";
    };
in {
  options.modules = {
    homeManager = classed "homeManager";
    nixos = classed "nixos";
  };
}
