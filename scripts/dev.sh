#!/usr/bin/env sh
# Run a command inside the Stuzer dev container without VS Code.
# Usage: scripts/dev.sh flutter test
# Mirrors .devcontainer/devcontainer.json: same image, caches, and adb socket.
# The /root/.android volume keeps the debug keystore stable across runs so
# every debug APK is signed with the same key and installs over the last one.
# The cmake volume keeps the CMake that Gradle installs on first build, which
# otherwise costs about a minute on every run.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd -W 2>/dev/null || cd "$(dirname "$0")/.." && pwd)"
exec docker run --rm -it \
  -v "$ROOT:/workspaces/stuzer" \
  -v stuzer-pub-cache:/caches/pub \
  -v stuzer-gradle-cache:/caches/gradle \
  -v stuzer-android-home:/root/.android \
  -v stuzer-android-cmake:/opt/android-sdk-linux/cmake \
  -w /workspaces/stuzer \
  -e ADB_SERVER_SOCKET=tcp:host.docker.internal:5037 \
  -e PUB_CACHE=/caches/pub \
  -e GRADLE_USER_HOME=/caches/gradle \
  ghcr.io/cirruslabs/flutter:stable "$@"
