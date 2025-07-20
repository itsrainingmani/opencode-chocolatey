$ErrorActionPreference = 'Stop'

$packageName = 'opencode'
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$version = $env:chocolateyPackageVersion

Uninstall-BinFile -Name $packageName

$exePath = Join-Path $toolsDir 'opencode.exe'
if (Test-Path $exePath) {
  Remove-Item -Path $exePath -Force
}

Write-Host "opencode $version has been uninstalled." -ForegroundColor Green