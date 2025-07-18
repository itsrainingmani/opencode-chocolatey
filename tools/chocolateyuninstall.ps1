$ErrorActionPreference = 'Stop'

$packageName = 'opencode'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

# Remove shim
Uninstall-BinFile -Name $packageName

# Remove the executable
$exePath = Join-Path $toolsDir 'opencode.exe'
if (Test-Path $exePath) {
  Remove-Item -Path $exePath -Force
}

Write-Host "OpenCode has been uninstalled." -ForegroundColor Green