{
  description = "Reproducible dev environment for WSL, managed by Nix + home-manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The dendritic pattern's two moving parts. flake-parts turns this flake's
    # outputs into a module system of their own, so a file can *contribute* to
    # an output instead of being wired into one by hand; import-tree collects
    # every file under ./modules so there is no imports list to keep in sync.
    #
    # Both are here on trial — see "M3's second experiment" in docs/status.md
    # for the criteria this has to meet to stay, and what would send it back.
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # M3's first experiment. `follows` is not optional housekeeping here:
    # NixOS-WSL pins its own nixpkgs, and without this the flake evaluates two
    # of them.
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # Inputs, and one line of wiring. Everything else is a module under ./modules,
  # collected recursively — which is the point of the pattern rather than
  # brevity for its own sake: there is no list here that can disagree with the
  # directory, and no file whose position in a list decides what it affects.
  #
  # Two consequences worth knowing before editing:
  #   - A new file under ./modules is loaded by existing. Nothing needs adding
  #     here, and a file that should *not* load must say so by name — a path
  #     containing `/_` is skipped by import-tree.
  #   - "What sets this option?" is answered by grep rather than by reading an
  #     imports list. That trade is one of the experiment's exit criteria.
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);
}
