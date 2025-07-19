$ErrorActionPreference = 'Stop'

$packageName = 'opencode'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

Uninstall-BinFile -Name $packageName

$exePath = Join-Path $toolsDir 'opencode.exe'
if (Test-Path $exePath) {
  Remove-Item -Path $exePath -Force
}

Write-Host "OpenCode has been uninstalled." -ForegroundColor Green