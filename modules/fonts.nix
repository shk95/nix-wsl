# Fonts, and a boundary this repository cannot cross.
#
# **What Nix can fix.** Anything that renders text inside Linux: WSLg GUI
# applications (DISPLAY and WAYLAND_DISPLAY are both set on this host), and any
# tool that draws its own glyphs through fontconfig. On the Ubuntu flavour this
# looks unnecessary, and today it is — `fc-match sans:lang=ko` already answers
# NanumGothic, because the distro ships it. That is the trap. The NixOS flavour
# has no distro:
#
#   nixosConfigurations.wsl.config.fonts.enableDefaultPackages  false
#   nixosConfigurations.wsl.config.fonts.packages               [ ]
#
# Zero fonts, so Korean has nothing to resolve to at all and every CJK glyph is
# a box. Contributed to `homeManager.shared` rather than to `nixos.wsl` deliberately: it
# is the flavour with the problem that gains, and the flavour without one loses
# nothing.
#
# **What Nix cannot fix.** The terminal. Windows Terminal renders with a Windows
# font chosen in its own settings.json, and a font in the Linux store is not
# visible to it — installing 194 MiB of Nerd Font here would not change one
# glyph in the terminal. So the prompt is written not to need one (see the
# emoji in modules/starship.nix), and the Windows-side step is documented where it
# will be looked for: docs/troubleshooting.md, under the symptom.
#
# Noto rather than Ubuntu's Nanum: it covers Korean, Japanese and Chinese in one
# package at 61 MiB against Nanum's 113 MiB for Korean alone, and it is the font
# fontconfig's own default rules already expect to find.
#
# **`fc-match` will answer "Noto Sans CJK JP" for Korean, and that is correct.**
# Worth knowing before it looks like a bug and earns a fix it does not need. The
# five regional families ship in one .ttc sharing one glyph set, and for
# `sans-serif` fontconfig offers a single candidate:
#
#   fc-match -s 'sans-serif:lang=ko'   ->  Noto Sans CJK JP   (the only one)
#   fc-match 'sans-serif:lang=ko' lang ->  ...|ja|ko|...      (declares Korean)
#   fc-match 'sans-serif:charset=ac00' ->  Noto Sans CJK JP   (has 가)
#
# So the family name is regional defaults for Han characters, not coverage. A
# preference rule for `Noto Sans CJK KR` was written and tested here: it changes
# `monospace` and cannot change `sans-serif`, because KR is not a candidate to
# promote. It was dropped rather than shipped half-working — Hangul is identical
# across the five, so nothing about 한글 depends on which one wins.
_: {
  modules.homeManager.shared = {pkgs, ...}: {
    # Generates the fontconfig that makes the profile's fonts discoverable. Without
    # it the packages below are in the store and invisible.
    fonts.fontconfig.enable = true;

    home.packages = [pkgs.noto-fonts-cjk-sans];
  };
}
