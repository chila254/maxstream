param(
    [string]$ExePath
)

# Promotes an installed MaxStream.exe to the user's Desktop (shortcut) and
# launches the app so it is easy to find and open. Intended to be run after a
# successful MSI install, either manually or via `gradlew desktop:promoteAndLaunch`.

if (-not $ExePath -or -not (Test-Path -LiteralPath $ExePath)) {
    Write-Error "Usage: desktop-shortcut.ps1 <path-to-MaxStream.exe>"
    exit 1
}

$exeDir = Split-Path -Parent $ExePath
$desktop = [Environment]::GetFolderPath("Desktop")
$lnk = Join-Path $desktop "MaxStream.lnk"

$ws = New-Object -ComObject WScript.Shell
$s = $ws.CreateShortcut($lnk)
$s.TargetPath = $ExePath
$s.WorkingDirectory = $exeDir
$s.IconLocation = "$ExePath,0"
$s.Description = "MaxStream for Windows"
$s.Save()

Write-Host "Shortcut created: $lnk"

Start-Process -FilePath $ExePath -WorkingDirectory $exeDir
Write-Host "Launched: $ExePath"