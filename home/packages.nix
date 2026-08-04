{pkgs, ...}: {
  home.packages = with pkgs; [
    # search / text — bat is programs/bat.nix, which also writes its config
    ripgrep
    fd
    fzf
    jq
    yq-go

    # git tooling beyond programs.git — gh is programs/gh.nix, which also
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
}
