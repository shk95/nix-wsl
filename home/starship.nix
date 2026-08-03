_: {
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[✗](bold red)";
      };

      git_branch = {
        symbol = "🌿 ";
        style = "bold purple";
      };
      git_state.style = "yellow";
      git_status = {
        style = "bold red";
        ahead = "⇡";
        behind = "⇣";
        diverged = "⇕";
        untracked = "?";
        modified = "!";
        staged = "+";
        deleted = "✘";
        renamed = "»";
        conflicted = "=";
        stashed = "$";
      };

      directory = {
        truncate_to_repo = true;
        style = "bold blue";
      };

      time = {
        format = "[$hour:$minute]($style) ";
        style = "bold white";
      };

      cmd_duration = {
        show_milliseconds = false;
        style = "bold magenta";
      };
    };
  };
}
