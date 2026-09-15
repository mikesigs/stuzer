# Start the adb server on the Windows host, listening on all interfaces,
# so the dev container can reach it at host.docker.internal:5037.
# Run once per session. The server keeps running in the background after
# this script exits; run it again any time to see the current state.
$ErrorActionPreference = "Stop"

if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
  Write-Host "adb is not on PATH. Install it with:  winget install --id Google.PlatformTools" -ForegroundColor Red
  Write-Host "Then open a new terminal so PATH is refreshed." -ForegroundColor Red
  exit 1
}

$listening = Get-NetTCPConnection -LocalPort 5037 -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "::" }

if ($listening) {
  Write-Host "adb server already listening on all interfaces, port 5037." -ForegroundColor Green
} else {
  Write-Host "Starting adb server on 0.0.0.0:5037 ..." -NoNewline
  & adb kill-server 2>$null
  Start-Process -WindowStyle Hidden -FilePath adb -ArgumentList "-a", "-P", "5037", "nodaemon", "server"
  $deadline = (Get-Date).AddSeconds(10)
  do {
    Start-Sleep -Milliseconds 300
    $listening = Get-NetTCPConnection -LocalPort 5037 -State Listen -ErrorAction SilentlyContinue |
      Where-Object { $_.LocalAddress -eq "0.0.0.0" -or $_.LocalAddress -eq "::" }
  } until ($listening -or (Get-Date) -gt $deadline)
  if (-not $listening) {
    Write-Host " failed." -ForegroundColor Red
    Write-Host "Port 5037 never opened. Is another adb (Android Studio?) holding it? Try: adb kill-server" -ForegroundColor Red
    exit 1
  }
  Write-Host " up." -ForegroundColor Green
}

Write-Host ""
Write-Host "Devices:"
$devices = (& adb devices -l | Select-Object -Skip 1 | Where-Object { $_.Trim() })
if ($devices) {
  $devices | ForEach-Object { Write-Host "  $_" }
  if ($devices -match "unauthorized") {
    Write-Host ""
    Write-Host "A device is unauthorized: unlock the phone and tap Allow on the USB debugging prompt (tick 'Always allow')." -ForegroundColor Yellow
  }
} else {
  Write-Host "  none. Plug in a phone with USB debugging enabled, then run this again." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "The container reaches this server through ADB_SERVER_SOCKET=tcp:host.docker.internal:5037."
Write-Host "Inside the container, 'flutter devices' should list the same phone."
