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

function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments)][string[]]$Args)
  $out = & adb @Args 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "adb $($Args -join ' ') failed:`n$($out -join "`n")"
  }
  $out
}

$state = (& adb get-state 2>&1)
if ($state -ne "device") {
  throw "No authorized device (adb get-state said '$state'). Plug in and accept the USB debugging prompt."
}

$tmp = "/data/local/tmp/stuzer.json"
Invoke-Adb push $Config $tmp | Out-Null
Invoke-Adb shell run-as $Package sh -c "'mkdir -p files && cp $tmp files/stuzer.json && cat files/stuzer.json'"
Invoke-Adb shell am force-stop $Package | Out-Null
Invoke-Adb shell am start -n "$Package/.MainActivity" | Out-Null
Write-Host "Pushed $Config and restarted $Package"
