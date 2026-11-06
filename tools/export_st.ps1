$ErrorActionPreference = 'Stop'
. 'C:\Users\SimonNiklasNiklasEng\Nextcloud\05_Standards_Normen\06_Beckhoff_TwinCAT\Hilfsskripte_XAE\xae.ps1'
$dte = Get-Xae -Solution 'C:\Beckhoff\TwinCAT\P016\P016.sln'
$sm  = Get-XaeSysManager
$root = 'C:\Beckhoff\TwinCAT\P016\_Repo\twincat\PLC\src'
$base = 'TIPC^P016_PLC^P016_PLC Project'

# vorhandene Dateien im Repo: Name -> Ordner (so bleibt die bestehende Struktur erhalten)
$existing = @{}
Get-ChildItem $root -Recurse -Filter *.st | ForEach-Object { $existing[$_.BaseName] = $_.Directory.Name }

function Get-Folder([string]$name) {
    if ($existing.ContainsKey($name)) { return $existing[$name] }
    if ($name -like 'GVL_*') { return '0_Main' }
    if ($name -like 'PRG_*') { return '0_Main' }
    if ($name -like 'FB_AxisMap*') { return '1_IO' }
    if ($name -like 'FB_Axis*' -or $name -like 'FB_Spindle*') { return '2_Devices' }
    if ($name -like 'FB_MFunctions*' -or $name -like 'FB_Cnc*') { return '3_Cnc' }
    if ($name -like 'FB_Alarm*' -or $name -like 'F_*') { return '5_Messages' }
    if ($name -like 'E_*' -or $name -like 'ST_*') { return '6_Interfaces' }
    if ($name -like 'FB_*') { return '4_Machine' }
    return '7_Weitere'
}

function Get-EndKeyword([string]$decl) {
    $first = ($decl -replace '(?s)\(\*.*?\*\)', '' -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -notlike '{attribute*' -and $_ -notlike '//*' } | Select-Object -First 1)
    if ($first -match '^FUNCTION_BLOCK\b') { return 'END_FUNCTION_BLOCK' }
    if ($first -match '^PROGRAM\b')        { return 'END_PROGRAM' }
    if ($first -match '^FUNCTION\b')       { return 'END_FUNCTION' }
    return $null
}

$written = @(); $skipped = @()
foreach ($sub in 'POUs','DUTs','GVLs') {
    $folder = $sm.LookupTreeItem("$base^$sub")
    for ($i = 1; $i -le $folder.ChildCount; $i++) {
        $c = $folder.Child($i)
        $name = $c.Name
        $decl = ''; $impl = ''
        try { $decl = [string]$c.DeclarationText } catch { }
        try { $impl = [string]$c.ImplementationText } catch { }
        if (-not $decl) { $skipped += "$sub/$name (kein Text)"; continue }
        $decl = $decl.TrimEnd() -replace "`r`n", "`n"
        $impl = ($impl -replace "`r`n", "`n").Trim()
        $end = Get-EndKeyword $decl
        $text = $decl + "`n"
        if ($end) {
            if ($impl) { $text += "`n" + $impl + "`n" }
            $text += $end + "`n"
        }
        $dir = Join-Path $root (Get-Folder $name)
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
        $file = Join-Path $dir ($name + '.st')
        [System.IO.File]::WriteAllText($file, $text, (New-Object System.Text.UTF8Encoding($false)))
        $written += "$sub/$name -> $((Get-Folder $name))"
    }
}
"Geschrieben: $($written.Count)"
$written | ForEach-Object { "  $_" }
if ($skipped.Count) { "Uebersprungen: " + ($skipped -join '; ') }
