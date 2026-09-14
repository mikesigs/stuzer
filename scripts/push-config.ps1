# Push config/stuzer.json to the debug build on the connected phone and
# bring the app to the front so it reloads. No rebuild needed.
#
# The file lives in the app's private storage, which adb can only reach
# through run-as on a debuggable build.
param(
  [string]$Config = (Join-Path $PSScriptRoot "..\config\stuzer.json"),
  [string]$Package = "com.mikesigs.stuzer"
)
$ErrorActionPreference = "Stop"
$tmp = "/data/local/tmp/stuzer.json"
adb push $Config $tmp | Out-Null
adb shell run-as $Package sh -c "mkdir -p files && cp $tmp files/stuzer.json && cat files/stuzer.json"
adb shell am force-stop $Package
adb shell am start -n "$Package/.MainActivity" | Out-Null
Write-Host "Pushed $Config and restarted $Package"
