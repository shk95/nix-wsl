# One system, and that is a rule rather than a current state.
#
# Everything here targets WSL, and `tool/checks/test` assumes it — a
# configuration for another system is refused outright rather than
# half-verified. Adding one is not a small change: it re-opens the question of
# what "verified" means for a build this machine cannot run.
#
# Which is also why there is no `forAllSystems` anywhere in this flake. The
# entire purpose of that helper is the case this repository declines, so it would
# make the wiring look more like other people's flakes while being strictly
# harder to read.
_: {
  systems = ["x86_64-linux"];
}
