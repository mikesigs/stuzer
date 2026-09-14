# Agent Skills

### Issue tracker

Issues and specs live in GitHub Issues. Skills use the `gh` CLI for all operations. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context layout with `CONTEXT.md` at the repo root and architecture decisions under `docs/adr/`. See `docs/agents/domain.md`.

### Toolchain

Flutter lives only in the Dev Container (`.devcontainer/`); nothing Flutter-related is installed on the Windows host except `adb`. Run any Flutter or Dart command through `scripts/dev.sh`, for example `scripts/dev.sh flutter test`. From PowerShell, use the equivalent `docker run` line found in that script. See `README.md` for the phone and adb setup.

### Architecture

`lib/domain/` is a pure Dart state machine with no Flutter imports; every rule in the spec has a test in `test/domain/`. Change rules there first, test-first, then adjust `lib/game/` (Flutter glue and painting) and `lib/audio/` (synthesised sounds). Keep platform-specific code out so the iOS build stays a build task.
