# Installs (or removes) Hardcore Tactical Realism in a SpaceBourne 2 folder.
# The game executable is never modified: UE4SS loads through dwmapi.dll next to it
# and the mod lives in SB2\Binaries\Win64\Mods\HardcoreTacticalRealism.
param(
    [string]$Game,       # the "SpaceBourne 2" folder (auto-detected for Steam when omitted)
    [string]$UE4SS,      # folder with UE4SS.dll, dwmapi.dll and UE4SS-settings.ini (default: .\ue4ss)
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'
$Name = 'HardcoreTacticalRealism'

function Find-Game {
    $roots = @()
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $roots += Join-Path $steam 'steamapps'
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object {
                # plain strings: Join-Path fails on libraries whose drive is not connected
                $roots += (($_.Matches[0].Groups[1].Value -replace '\\\\', '\').TrimEnd('\') + '\steamapps')
            }
        }
    }
    foreach ($r in $roots) {
        $g = "$r\common\SpaceBourne 2"
        if (Test-Path -LiteralPath "$g\SB2\Binaries\Win64\SB2-Win64-Shipping.exe" -ErrorAction SilentlyContinue) { return $g }
    }
    return $null
}

if (-not $Game) { $Game = Find-Game }
if (-not $Game) { throw "SpaceBourne 2 not found. Run again with -Game 'C:\path\to\SpaceBourne 2' (GOG: your install folder)." }
if (-not $UE4SS) { $UE4SS = Join-Path $PSScriptRoot 'ue4ss' }
$win64 = Join-Path (Resolve-Path $Game).Path 'SB2\Binaries\Win64'
if (-not (Test-Path (Join-Path $win64 'SB2-Win64-Shipping.exe'))) {
    throw "SpaceBourne 2 not found in '$Game' (expected SB2\Binaries\Win64\SB2-Win64-Shipping.exe)."
}
$marker = Join-Path $win64 'HTR-installed-UE4SS.txt'   # present only if this script installed UE4SS
$entry = "^\s*$Name\s*:"
$mods = Join-Path $win64 'Mods'
$modsTxt = Join-Path $mods 'mods.txt'

if ($Uninstall) {
    if (Test-Path (Join-Path $mods $Name)) { Remove-Item (Join-Path $mods $Name) -Recurse -Force }
    if (Test-Path $modsTxt) { Set-Content $modsTxt -Value @(Get-Content $modsTxt | Where-Object { $_ -notmatch $entry }) -Encoding ASCII }
    if (Test-Path $marker) {
        $others = Get-ChildItem $mods -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @('shared', 'Keybinds') }
        if ($others) {
            Write-Warning "Other UE4SS mods are installed, so UE4SS itself was left in place."
        } else {
            'dwmapi.dll', 'UE4SS.dll', 'UE4SS-settings.ini', 'UE4SS.log' | ForEach-Object { Remove-Item (Join-Path $win64 $_) -ErrorAction SilentlyContinue }
            Remove-Item $mods -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item $marker
        }
    }
    Write-Host "Hardcore Tactical Realism removed from $win64"
    return
}

# Reuse an existing UE4SS (another mod may have installed it); otherwise install the bundled one.
if (-not (Test-Path (Join-Path $win64 'UE4SS.dll'))) {
    if (Test-Path (Join-Path $win64 'dwmapi.dll')) { throw "The game folder already has a dwmapi.dll from another mod loader. Remove it, or install UE4SS yourself first." }
    if (-not (Test-Path (Join-Path $UE4SS 'UE4SS.dll'))) { throw "UE4SS not found in '$UE4SS'." }
    Copy-Item (Join-Path $UE4SS 'dwmapi.dll'), (Join-Path $UE4SS 'UE4SS.dll') $win64 -Force
    (Get-Content (Join-Path $UE4SS 'UE4SS-settings.ini')) -replace '^GuiConsoleEnabled\s*=.*', 'GuiConsoleEnabled = 0' |
        Set-Content (Join-Path $win64 'UE4SS-settings.ini') -Encoding ASCII
    'UE4SS was installed by Hardcore Tactical Realism. "Install.ps1 -Uninstall" removes it.' | Set-Content $marker -Encoding ASCII
}

# Copy the mod, keeping the player's config.lua and state.txt from an earlier install.
$dest = Join-Path $mods $Name
$keepCfg = $null
if (Test-Path (Join-Path $dest 'scripts\config.lua')) { $keepCfg = Get-Content (Join-Path $dest 'scripts\config.lua') -Raw }
New-Item -ItemType Directory -Force (Join-Path $dest 'scripts\htr') | Out-Null
# A Nexus "lite" install enables itself with enabled.txt; mods.txt takes over now (never both).
Remove-Item (Join-Path $dest 'enabled.txt') -ErrorAction SilentlyContinue
Copy-Item (Join-Path $PSScriptRoot "mod\$Name\scripts\*.lua") (Join-Path $dest 'scripts') -Force
Copy-Item (Join-Path $PSScriptRoot "mod\$Name\scripts\htr\*.lua") (Join-Path $dest 'scripts\htr') -Force
if ($keepCfg) {
    Copy-Item (Join-Path $dest 'scripts\config.lua') (Join-Path $dest 'scripts\config.default.lua') -Force
    Set-Content (Join-Path $dest 'scripts\config.lua') -Value $keepCfg -NoNewline -Encoding ASCII
    Write-Host "Kept your config.lua (the new defaults are in config.default.lua)."
}

# Enable it in mods.txt, before UE4SS's built-in Keybinds entry when present.
$lines = [Collections.Generic.List[string]]@(if (Test-Path $modsTxt) { Get-Content $modsTxt })
$at = $lines.FindIndex([Predicate[string]] { param($l) $l -match $entry })
if ($at -ge 0) { $lines[$at] = "$Name : 1" } else {
    $kb = $lines.FindIndex([Predicate[string]] { param($l) $l -match '^\s*Keybinds\s*:' })
    if ($kb -ge 0) { $lines.Insert($kb, "$Name : 1") } else { $lines.Add("$Name : 1") }
}
Set-Content $modsTxt -Value $lines -Encoding ASCII
Write-Host "Hardcore Tactical Realism installed in $win64"
Write-Host "Settings: $dest\scripts\config.lua   (F7 in game cycles Tactical / Tactical Hardcore / Realism / Realism Hardcore)"
