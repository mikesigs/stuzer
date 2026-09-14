# Stuzer

Decides who goes first in a board game. Everyone rests a finger on one shared
phone or tablet, a countdown runs, and the fastest finger off the screen after
**Go** is the first player. Every other finger gets a place by lift time.

The rules and vocabulary live in [CONTEXT.md](CONTEXT.md). The spec is
[issue #1](https://github.com/mikesigs/stuzer/issues/1).

## Layout

| Path | What |
| --- | --- |
| `lib/domain/` | Pure Dart Round state machine. No Flutter, no timers. Every rule is tested in `test/domain/`. |
| `lib/game/` | Flutter glue: pointer events and timers into the Round, painter, overlay text. |
| `lib/audio/` | Synthesised sounds (no audio assets) played through `flutter_soloud`. |
| `.devcontainer/` | VS Code Dev Container with Flutter, Android SDK, and JDK. |
| `scripts/` | Helpers for running the container and the host `adb` server. |

## Developing

Everything runs inside the Dev Container. Only `adb` runs on Windows so the
container can reach a phone over USB.

One-time host setup (Windows):

```powershell
winget install --id Google.PlatformTools
```

Each session, start the host adb server so the container can reach it:

```powershell
scripts\adb-host.ps1
```

Then either open the folder in VS Code and choose **Reopen in Container**, or
run commands directly:

```bash
scripts/dev.sh flutter test
scripts/dev.sh flutter analyze
scripts/dev.sh flutter run
```

Phone setup: enable Developer options, turn on USB debugging, plug in, and
accept the "allow USB debugging" prompt. `adb devices` on the host should list
it; `flutter devices` in the container will then see it too.

If the cable is a nuisance, Android 11+ wireless debugging works instead:
pair from the host with `adb pair`, then `adb connect <ip>:<port>`.

## Tuning without a rebuild

Timings live in [config/stuzer.json](config/stuzer.json). Durations are in
seconds and may be fractional. Push it to the phone and the app restarts
with the new values:

```powershell
scripts\push-config.ps1
```

The app reads the file at startup and again whenever it returns to the
foreground, so you can also edit it on the device and just switch away and
back. The active timings show in small text at the bottom-left while the
screen is empty. On first run the app writes its defaults to the same place
(`/data/data/com.mikesigs.stuzer/files/stuzer.json`, reachable through
`adb shell run-as`). Missing or invalid keys fall back to the built-in
defaults, which match the spec.

## Rules in one breath

Two or more fingers unchanged for 3 s lock in. One locked beat, then
3, 2, 1 at one per second, then Go. If everyone lets go before the "1"
count the Round is abandoned. Lifts after Go rank by time. Lifts
before Go are False Starts and rank behind everyone, earliest jump last.
Fingers still held 5 s after Go are Stragglers and rank behind all who lifted.
Every tie goes to the finger that landed first.
