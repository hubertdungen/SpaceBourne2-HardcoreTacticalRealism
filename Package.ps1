# Builds release\HardcoreTacticalRealism-<version>.zip from this folder.
param([string]$Version = "0.1.0")
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$name = "HardcoreTacticalRealism-$Version"
$out = Join-Path $root "release\$name"
if (Test-Path $out) { Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Force "$out\mod\HardcoreTacticalRealism\scripts\htr", "$out\ue4ss" | Out-Null
Copy-Item "$root\mod\HardcoreTacticalRealism\scripts\*.lua" "$out\mod\HardcoreTacticalRealism\scripts\"
Copy-Item "$root\mod\HardcoreTacticalRealism\scripts\htr\*.lua" "$out\mod\HardcoreTacticalRealism\scripts\htr\"
Copy-Item "$root\ue4ss\*" "$out\ue4ss\"
Copy-Item "$root\Install.ps1", "$root\Install.cmd", "$root\Uninstall.cmd", "$root\README.md", "$root\CHANGELOG.md", "$root\LICENSE", "$root\THIRD-PARTY-NOTICES.txt" $out
$main = Get-Content "$root\mod\HardcoreTacticalRealism\scripts\main.lua" -Raw
if ($main -notmatch "VERSION = `"$([regex]::Escape($Version))`"") { throw "main.lua VERSION does not match $Version" }
$zip = Join-Path $root "release\$name.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path "$out\*" -DestinationPath $zip

# Nexus "lite" build: no executables (Nexus quarantines DLL/CMD/PS1). Extract into the
# "SpaceBourne 2" folder; enabled.txt makes UE4SS load it without editing mods.txt.
$lite = Join-Path $root "release\$name-lite"
if (Test-Path $lite) { Remove-Item $lite -Recurse -Force }
$liteMod = "$lite\SB2\Binaries\Win64\Mods\HardcoreTacticalRealism"
New-Item -ItemType Directory -Force "$liteMod\scripts\htr" | Out-Null
Copy-Item "$out\mod\HardcoreTacticalRealism\scripts\*.lua" "$liteMod\scripts\"
Copy-Item "$out\mod\HardcoreTacticalRealism\scripts\htr\*.lua" "$liteMod\scripts\htr\"
New-Item -ItemType File "$liteMod\enabled.txt" | Out-Null
Copy-Item "$root\README.md", "$root\CHANGELOG.md", "$root\LICENSE" $liteMod
$liteZip = Join-Path $root "release\$name-lite.zip"
if (Test-Path $liteZip) { Remove-Item $liteZip }
Compress-Archive -Path "$lite\*" -DestinationPath $liteZip
Get-Item $zip, $liteZip | Select-Object Name, Length
