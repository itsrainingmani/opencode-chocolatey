$ErrorActionPreference = 'Stop'

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageName = 'opencode'
$version = $env:chocolateyPackageVersion

$url64 = "https://github.com/sst/opencode/releases/download/v$version/opencode-windows-x64.zip"

Write-Host "opencode $version"

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  url64bit       = $url64
  checksum64     = '09C99FAFFD0BAFD7A33D370B8AC5E98B1A7BD57984FD6D63B1F04F4429CDE7AC'  # This should be updated by the update script
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

$exePath = Join-Path $toolsDir 'opencode.exe'

if (-not (Test-Path $exePath)) {

  $exeFiles = Get-ChildItem -Path $toolsDir -Filter 'opencode.exe' -Recurse
  if ($exeFiles.Count -gt 0) {
    $sourceExe = $exeFiles[0].FullName
    Move-Item -Path $sourceExe -Destination $exePath -Force

    $parentDir = Split-Path -Parent $sourceExe
    if ((Get-ChildItem -Path $parentDir -Force).Count -eq 0) {
      Remove-Item -Path $parentDir -Recurse -Force
    }
  }
  else {
    throw "opencode.exe not found in the extracted files"
  }
}

Install-BinFile -Name 'opencode' -Path $exePath
Write-Host "opencode $version has been installed successfully!" -ForegroundColor Green
Write-Host "Run 'opencode' to start using it." -ForegroundColor Green