$ErrorActionPreference = 'Stop'

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageName = 'opencode'
$version = $env:chocolateyPackageVersion

$url64 = "https://github.com/anomalyco/opencode/releases/download/v$version/opencode-windows-x64.zip"

Write-Host "opencode $version"

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  url64bit       = $url64
  checksum64     = 'E31D83FC1C2EB54D707F6F36529BCB8B01B1A2AB50C485C478B5C10E64F1CFFF'  # This should be updated by the update script
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