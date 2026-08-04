_: {
  modules.homeManager.shared = {lib, ...}: {
    # The login shell moves from bash to zsh with M2. What is left below was in an
    # unmanaged ~/.bashrc, which home-manager does not touch — so nothing would
    # have carried over on its own, and the switch would have looked like the
    # environment regressing rather than moving.
    #
    # Two of those bridges have since gone. conda is replaced by uv
    # (modules/uv.nix), and the `sysmetrics` banner belongs to a project outside
    # this repository and will be declared when it is ready. Both are still in
    # ~/.bashrc, which this flake does not manage and which stays a working
    # fallback on purpose: removing a hook here does not remove it there, and if
    # zsh ever fails to start, bash is what you land in.
    home.sessionVariables = {
      # The system default is C.UTF-8 (/etc/default/locale); en_US.UTF-8 was set
      # per-shell in ~/.bashrc. Declared here so it does not depend on which
      # shell happens to start.
      #
      # No LOCALE_ARCHIVE. The usual advice on a non-NixOS host is to pin
      # pkgs.glibcLocales, but it is not needed here: nix's glibc falls back to
      # /usr/lib/locale/locale-archive, which Ubuntu generates with en_US.UTF-8
      # in it. Verified by strace, and by `locale charmap` returning UTF-8 rather
      # than ANSI_X3.4-1968 — the latter is the symptom if this ever stops
      # holding, and pinning glibcLocales is the fix at that point.
      LANG = "en_US.UTF-8";
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      syntaxHighlighting.enable = true;

      # Completion behaviour belongs here rather than in initContent. `zstyle` is
      # read by the completion system when a completion actually runs, so the two
      # are identical in effect — but this option only exists when
      # `enableCompletion` is on, which makes the dependency structural instead of
      # something a reader has to notice.
      completionInit = ''
        autoload -Uz compinit
        compinit

        # Lowercase input matches uppercase names: `~/dow<tab>` finds `Downloads`.
        # One-directional on purpose — uppercase input stays exact, so a name
        # typed in full case still means what it says.
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      '';

      initContent = lib.mkOrder 1000 ''
        # ~/.zshrc sourced ~/.local/bin/env, and that was the only thing putting
        # this directory on PATH — but home-manager takes ~/.zshrc over, so
        # without this, activation silently removes claude.
        #
        # Not home.sessionPath, which prepends:
        #   export PATH="$HOME/.local/bin''${PATH:+:}$PATH"
        # The directory holds standalone installers' output that overlaps what
        # this flake declares — a `bat` symlink to Ubuntu's `batcat`, and a 66 MB
        # `uv` from its own installer — and in both cases the declared package
        # should win. Appending keeps that order while still resolving `claude`,
        # which lives only here. Prepending would silently hand `uv` back to the
        # copy nothing updates.
        #
        # `typeset -U path` also fixes a pre-existing duplicate: the directory
        # appeared twice in PATH under bash.
        typeset -U path
        path+=("$HOME/.local/bin")
        path+=("$HOME/.opencode/bin")

        # SDKMAN, and the one imperative installer left in here. There is no
        # `sdkman` in nixpkgs — it is a shell function that downloads its own JDKs
        # into ~/.sdkman and rewrites PATH — so "add it as a package" is not
        # available, and this hook is the whole integration. Guarded, so a shell
        # still starts once it is uninstalled.
        #
        # The Nix answer to several JDKs is a devShell per project, which direnv
        # already loads here (modules/direnv.nix). Migrating to that means giving
        # up `sdk use` in shells that are not project directories, so it is a
        # deliberate change rather than a cleanup, and it has not been made.
        #
        # Last on purpose: it rewrites PATH and expects to win.
        export SDKMAN_DIR="$HOME/.sdkman"
        [ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
      '';
    };
  };
}
