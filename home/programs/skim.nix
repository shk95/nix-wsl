_: {
  # skim provides a single executable, `sk`, plus shell keybindings
  # (ctrl-r / ctrl-t / alt-c) compatible with fzf's integration scripts.
  programs.skim = {
    enable = true;
    enableZshIntegration = true;
  };
}
