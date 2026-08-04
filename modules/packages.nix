# Packages with nothing to configure. Anything that has a home-manager module —
# and so a config file to generate — gets its own file instead; `bat` moved out of
# here for exactly that reason, and `programs.bat` contributes the package itself.
#
# These are home-manager packages rather than `environment.systemPackages`, and
# that is the deliberate direction rather than an accident of where the repository
# started. Under the NixOS flavour `useUserPackages = true` already folds them
# into the system closure — they are built by `nixos-rebuild`, roll back with the
# generation, and land in /etc/profiles/per-user — so moving them to the system
# layer would buy only availability to root, and would cost the standalone flavour
# every one of them, because `environment.*` does not exist there. The test for a
# new package is that question: would standalone still work if this lived only in
# `modules/wsl.nix`?
_: {
  modules.homeManager.shared = {pkgs, ...}: {
    home.packages = with pkgs; [
      # search / text
      ripgrep
      fd
      fzf
      jq
      yq-go

      # git tooling beyond programs.git — gh is modules/gh.nix, which also
      # generates the credential helper
      tig

      # the pre-commit hook's secret scan is a no-op without this, and on a
      # public repository CI only catches a leak after it is already published
      gitleaks

      # archives
      unzip
      zip
      xz
      zstd

      # network
      curl
      wget

      # session / monitoring
      tmux
      btop

      tree
      just
      gnupg
    ];
  };
}
