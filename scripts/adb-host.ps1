# Start the adb server on the Windows host, listening on all interfaces,
# so the dev container can reach it at host.docker.internal:5037.
# Run once per session (leave the window open, or run in background).
adb kill-server 2>$null
adb -a -P 5037 nodaemon server
