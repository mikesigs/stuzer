# Stuzer

Decides who goes first in a board game. Everyone rests a finger on one shared
phone or tablet, a countdown runs, and the fastest finger off the screen after
**Go** is the first player. Every other finger gets a place by lift time.

The rules and vocabulary live in [CONTEXT.md](CONTEXT.md). The spec is
[issue #1](https://github.com/mikesigs/stuzer/issues/1).

## Layout

| Path | What |
| --- | --- |
| `lib/domain/` | Pure Dart Round shell (Gathering, Lock-in, Results, Aborted). No Flutter, no timers. Tested in `test/domain/`. |
| `lib/domain/modes/` | One folder per Mode: its session state machine, config, and effects. Race and Classic today. |
| `lib/game/` | Flutter glue: pointer events and timers into the Round, shared painter, mode picker. |
| `lib/game/modes/` | Each Mode's presentation and the registry that lists them. |
| `lib/audio/` | Synthesised sounds (no audio assets) played through `flutter_soloud`. |
| `.devcontainer/` | VS Code Dev Container with Flutter, Android SDK, and JDK. |
| `scripts/` | Helpers for running the container and the host `adb` server. |

## Developing

Everything Flutter runs inside the Dev Container. Windows keeps only `adb`
so the container can reach a phone over USB.

### One-time host setup (Windows)

```powershell
winget install --id Google.PlatformTools
```

Open a new terminal afterwards so `adb` is on your PATH.

### Each session, on Windows

Start the host adb server. It prints what it did and which devices it
sees, then keeps running in the background:

```powershell
scripts\adb-host.ps1
```

Phone setup: enable Developer options, turn on USB debugging, plug in, and
accept the "Allow USB debugging" prompt with "Always allow" ticked.

### Working inside the container (recommended)

Open the folder in VS Code and choose **Reopen in Container**. In the
container's terminal, Flutter is already on the PATH, so run commands
directly:

```bash
flutter devices        # should list your phone, via the host adb server
flutter test
flutter analyze
flutter run            # hot reload on the phone
```

### Working from Windows without VS Code

`scripts/dev.sh` is a wrapper for the *Windows* side: it starts the same
container image with the same mounts and runs one command in it. Run it from
Git Bash, not from inside the container (the container has no Docker):

```bash
scripts/dev.sh flutter test
```

If the cable is a nuisance, Android 11+ wireless debugging works instead:
pair from the host with `adb pair`, then `adb connect <ip>:<port>`.

## Tuning without a rebuild

Timings live in [config/stuzer.json](config/stuzer.json). Durations are in
seconds and may be fractional. Push it to the phone and the app restarts
with the new values:

```powershell
scripts\push-config.ps1
```

Top-level keys tune Gathering and the beat. `modes.race` holds
`countdownFrom` and a `straggler` section: `afterSeconds` (teasing starts
this long after Go), `messageCount`, `messageSeconds` (how long each line
stays up), and `messages`, the pool of lines. Each Race draws `messageCount`
lines at random with no repeats and closes at
`afterSeconds + messageCount * messageSeconds`. `modes.classic` holds
`suspenseSeconds`, `firstHopMs`, `hopGrowth`, and `maxHopMs` for the
spotlight's rhythm.

The app reads the file at startup and again whenever it returns to the
foreground, so you can also edit it on the device and just switch away and
back. The active timings show in small text at the bottom-left while the
screen is empty. On first run the app writes its defaults to the same place
(`/data/data/com.mikesigs.stuzer/files/stuzer.json`, reachable through
`adb shell run-as`). Missing or invalid keys fall back to the built-in
defaults, which match the spec.

## Modes

**Race** (default): after Go, fastest finger off the screen goes first.
**Classic**: a spotlight hops between fingers with a slowing rhythm and
stops on one. Switch with the pill at the bottom of the empty screen; the
choice is remembered. Adding a Mode means a folder under `lib/domain/modes/`,
a presentation under `lib/game/modes/`, and one line in the registry.

## Race rules in one breath

Two or more fingers unchanged for 3 s lock in. One locked beat, then
3, 2, 1 at one per second, then Go. If everyone lets go before the "1"
count the Round is abandoned. Lifts after Go rank by time. Lifts
before Go are False Starts and rank behind everyone, earliest jump last.
Fingers still held 5 s after Go are Stragglers and rank behind all who lifted.
Every tie goes to the finger that landed first.
