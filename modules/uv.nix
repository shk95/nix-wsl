# Replaces conda, whose hook is gone from modules/shell.nix. `~/miniconda3` is
# still on disk and still wired into the unmanaged ~/.bashrc; nothing here removes
# either.
#
# No `settings`. uv reads ~/.config/uv/uv.toml and this module will write it, but
# every value worth setting is already uv's default, and a file full of restated
# defaults is the exact failure that modules/starship.nix exists to record.
# It goes in when there is a reason.
#
# One thing is worth knowing before the NixOS flavour uses this. uv prefers to
# download its own CPython, and those are portable builds with a hardcoded
# interpreter path — fine on Ubuntu, and they do not run on NixOS without nix-ld.
# uv's default `python-preference` falls back to a system interpreter, so the fix
# if it bites is either a declared python3 or nix-ld in modules/wsl.nix, and not a
# setting here. Untested under NixOS-WSL: no reason to guess at it before the
# flavour is in use.
_: {
  # The package ships its own `_uv` completion, which programs.zsh picks up from
  # the profile's share/zsh/site-functions — so, as expected, there is no shell
  # wiring to add.
  modules.homeManager.shared.programs.uv.enable = true;
}
