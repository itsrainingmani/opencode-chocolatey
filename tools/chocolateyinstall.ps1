$ErrorActionPreference = 'Stop'

$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$packageName = 'opencode'
$version = $env:chocolateyPackageVersion

# Construct the download URL based on the package version
$url64 = "https://github.com/sst/opencode/releases/download/v$version/opencode-windows-x64.zip"

Write-Host "Installing OpenCode version $version"

$packageArgs = @{
  packageName    = $packageName
  unzipLocation  = $toolsDir
  url64bit       = $url64
  checksum64     = 'B9E64582668690E0144D03DA8BC2CABA5613F4A6BBEF4FCDACE1CF2F482E1137'  # This should be updated by the update script
  checksumType64 = 'sha256'
}

try {
  # Check if the URL exists before attempting download
  try {
    Invoke-WebRequest -Uri $url64 -Method Head -UseBasicParsing
  }
  catch {
    throw "OpenCode version $version not found at $url64. Please check if this version exists on GitHub."
  }

  # Install the package
  Install-ChocolateyZipPackage @packageArgs
    
  # The zip should contain the opencode.exe at the root
  $exePath = Join-Path $toolsDir 'opencode.exe'
    
  if (-not (Test-Path $exePath)) {
    # Check if it's in a subdirectory
    $exeFiles = Get-ChildItem -Path $toolsDir -Filter 'opencode.exe' -Recurse
    if ($exeFiles.Count -gt 0) {
      $sourceExe = $exeFiles[0].FullName
      Move-Item -Path $sourceExe -Destination $exePath -Force
            
      # Clean up empty directories
      $parentDir = Split-Path -Parent $sourceExe
      if ((Get-ChildItem -Path $parentDir -Force).Count -eq 0) {
        Remove-Item -Path $parentDir -Recurse -Force
      }
    }
    else {
      throw "opencode.exe not found in the extracted files"
    }
  }
    
  # Create shim
  Install-BinFile -Name 'opencode' -Path $exePath
    
  Write-Host "OpenCode $version has been installed successfully!" -ForegroundColor Green
  Write-Host "Run 'opencode' to start using it." -ForegroundColor Green
    
}
catch {
  throw "Failed to install OpenCode: $_"
}