{pkgs, ...}: {
  home.packages = with pkgs; [
    # search / text
    ripgrep
    fd
    fzf
    bat
    jq
    yq-go

    # git tooling beyond programs.git
    gh
    tig

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
