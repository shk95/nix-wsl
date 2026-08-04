_: {
  # skim provides a single executable, `sk`, plus shell keybindings
  # (ctrl-r / ctrl-t / alt-c) compatible with fzf's integration scripts.
  modules.homeManager.shared = {
    programs.skim = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}
