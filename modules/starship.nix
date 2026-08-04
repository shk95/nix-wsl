# Every key below changes a starship default, and that is the point of the
# rewrite rather than a coincidence. The version this replaces set 28 keys of
# which 20 restated the default exactly — it read as a configured prompt while
# doing nothing, and the noise hid two real defects among the eight lines that
# did have an effect.
#
# The check is mechanical, because starship will print its computed
# configuration with the defaults filled in:
#
#   STARSHIP_CONFIG=/dev/null starship print-config > default.toml
#   starship print-config                           > ours.toml
#   diff default.toml ours.toml
#
# Anything absent from that diff can be deleted without changing the prompt.
# Worth re-running after a starship upgrade: a moved default turns a line here
# into a no-op, or a deletion into a change.
_: {
  modules.homeManager.shared = {
    programs.starship = {
      enable = true;
      enableZshIntegration = true;

      settings = {
        # Default is `❯` in red for both states. A different glyph reads faster
        # than a colour change on a prompt that is already coloured, and it
        # survives a terminal palette where red and green sit close together.
        character.error_symbol = "[✗](bold red)";

        directory = {
          style = "bold blue";
          # Default is the empty string, which makes a truncated path
          # indistinguishable from a short one: `nix-wsl` could be the repo root
          # or four levels down inside it.
          truncation_symbol = "…/";
        };

        # Emoji, not the default ``, which is a Nerd Font glyph. The terminal
        # here is Windows Terminal and its font is a Windows setting this flake
        # cannot reach, so relying on a Nerd Font would mean relying on a value
        # declared somewhere this repository does not own. See modules/fonts.nix.
        git_branch.symbol = "🌿 ";

        git_status = {
          # Counts, which the defaults omit: `⇡` says the branch is ahead, `⇡3`
          # says how much work is waiting to be pushed.
          ahead = "⇡$count";
          behind = "⇣$count";
          diverged = "⇕⇡$ahead_count⇣$behind_count";

          # The backslash is load-bearing, and its absence was a real bug. `$`
          # opens a variable reference in a starship format string, so the bare
          # `"$"` here before was parsed as one, resolved to nothing, and dropped
          # the stash indicator entirely — `[?]` with a stash present, where
          # starship's own default `'\$'` gives `[$?]`.
          stashed = "\\$$count";
        };

        cmd_duration.style = "bold magenta";

        # This module was configured, dead, *and* wrong — two independent defects
        # that hid each other. `disabled = true` is its default, so nothing here
        # ever rendered; and the format it carried was `[$hour:$minute]($style)`,
        # referring to two variables the module does not have. It exposes `$time`
        # and nothing else, so once enabled that format resolved to a bare `:`.
        # The clock shape belongs in `time_format`, which is strftime — `%R` is
        # `%H:%M`.
        time = {
          disabled = false;
          format = "[$time]($style) ";
          time_format = "%R";
          style = "bold white";
        };

        # By default this module reads IN_NIX_SHELL and nothing else, and the two
        # ways into a nix shell do not agree on setting it:
        #
        #   nix develop            IN_NIX_SHELL=impure   shown either way
        #   nix shell nixpkgs#hello  (unset)             shown only with this
        #
        # So the gap is `nix shell` — the form used to try a package for five
        # minutes, which is exactly when forgetting you are inside one is easy.
        nix_shell.heuristic = true;
      };
    };
  };
}
