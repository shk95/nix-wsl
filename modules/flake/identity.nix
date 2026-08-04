# Who this configuration is for, declared as options rather than threaded in.
#
# This replaces a `specialArgs` / `extraSpecialArgs` pair, and the pattern names
# passing values through module arguments as an anti-pattern. This repository is
# a good argument for that: the same three values were handed to two flavours
# separately, so they *could* disagree, and a disagreement would have surfaced as
# one flavour failing to evaluate rather than as anything a reader could see.
# They were deduplicated into a shared `homeArgs` attrset first; declaring them
# removes the shape of the problem instead of one instance of it.
#
# A declared option also carries its own documentation and type, which a function
# argument cannot, and `nix eval .#…config.identity` will answer questions about
# it without reading the file.
{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.identity = {
    user = mkOption {
      type = types.str;
      description = ''
        The unix account this configuration applies to — this WSL instance's
        login user. Deliberately separate from `gitName`: fusing the two makes
        every commit look like it came from a machine account.
      '';
    };

    gitName = mkOption {
      type = types.str;
      description = "Author name on commits, independent of the unix account.";
    };

    gitEmail = mkOption {
      type = types.str;
      description = "Author address on commits.";
    };
  };

  config.identity = {
    user = "user1";
    gitName = "shk";
    gitEmail = "101378576+shk95@users.noreply.github.com";
  };
}
