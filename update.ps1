# Enhanced update script with better error handling and features
param(
  [switch]$CheckOnly,
  [switch]$Force,
  [switch]$PreRelease,
  [string]$SpecificVersion,
  [switch]$AutoCommit
)

$ErrorActionPreference = 'Stop'

function Write-Log {
  param([string]$Message, [string]$Level = 'Info')
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $color = switch ($Level) {
    'Error' { 'Red' }
    'Warning' { 'Yellow' }
    'Success' { 'Green' }
    'Info' { 'Cyan' }
    default { 'White' }
  }
  Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

# Verify git status if AutoCommit is requested
if ($AutoCommit) {
  $gitStatus = git status --porcelain 2>$null
  if ($gitStatus) {
    Write-Log "Working directory has uncommitted changes. Please commit or stash them first." "Error"
    exit 1
  }
}

try {
  # Get current version from nuspec
  $nuspecPath = Join-Path $PSScriptRoot 'opencode.nuspec'
  if (-not (Test-Path $nuspecPath)) {
    throw "opencode.nuspec not found at $nuspecPath"
  }
  
  $nuspec = [xml](Get-Content $nuspecPath)
  $currentVersion = $nuspec.package.metadata.version
  
  if ($SpecificVersion) {
    $apiUrl = "https://api.github.com/repos/sst/opencode/releases/tags/v$SpecificVersion"
  }
  elseif ($PreRelease) {
    $apiUrl = 'https://api.github.com/repos/sst/opencode/releases'
  }
  else {
    $apiUrl = 'https://api.github.com/repos/sst/opencode/releases/latest'
  }
  
  # Add retry logic for API calls
  $maxRetries = 3
  $retryCount = 0
  $releaseInfo = $null
  
  while ($retryCount -lt $maxRetries -and -not $releaseInfo) {
    try {
      $headers = @{ 
        'User-Agent' = 'Chocolatey-Updater'
        'Accept'     = 'application/vnd.github.v3+json'
      }
      
      if ($PreRelease -and -not $SpecificVersion) {
        $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
        $releaseInfo = $releases | Where-Object { $_.prerelease -eq $false } | Select-Object -First 1
      }
      else {
        $releaseInfo = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get
      }
    }
    catch {
      $retryCount++
      if ($retryCount -eq $maxRetries) {
        throw "Failed to fetch release info after $maxRetries attempts: $_"
      }
      Write-Log "API call failed, retrying... ($retryCount/$maxRetries)" "Warning"
      Start-Sleep -Seconds 2
    }
  }
  
  $latestVersion = $releaseInfo.tag_name.TrimStart('v')
  
  Write-Log "Current version in nuspec: $currentVersion" "Info"
  Write-Log "Target version: $latestVersion" "Info"
  
  if ($currentVersion -eq $latestVersion -and -not $Force) {
    Write-Log "Package is up to date!" "Success"
    exit 0
  }
  
  # Find the Windows x64 asset
  $asset = $releaseInfo.assets | Where-Object { $_.name -eq 'opencode-windows-x64.zip' }
  if (-not $asset) {
    Write-Log "Windows x64 asset not available in release $latestVersion" "Warning"
    Write-Log "Release assets found: $($releaseInfo.assets.name -join ', ')" "Info"
    
    if ($CheckOnly) {
      # Exit with code 2 to indicate no update available due to missing asset
      exit 2
    }
    
    throw "Could not find Windows x64 asset in the release"
  }
  
  if ($CheckOnly) {
    Write-Log "Update available: $currentVersion -> $latestVersion" "Warning"
    Write-Log "Windows x64 asset is available for download" "Success"
    exit 1
  }
  
  Write-Log "Downloading release to calculate checksum..." "Info"
  $tempFile = Join-Path $env:TEMP "opencode-$latestVersion.zip"
  
  # Download with progress bar
  $progressPreference = 'Continue'
  try {
    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add('User-Agent', 'Chocolatey-Updater')
    
    # Register event for progress
    $eventDataComplete = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged -Action {
      $percent = $EventArgs.ProgressPercentage
      Write-Progress -Activity "Downloading OpenCode $latestVersion" -Status "$percent% Complete" -PercentComplete $percent
    }
    
    $webClient.DownloadFileAsync($asset.browser_download_url, $tempFile)
    
    # Wait for download
    while ($webClient.IsBusy) {
      Start-Sleep -Milliseconds 100
    }
    
    Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
    Write-Progress -Activity "Downloading" -Completed
    
    # Verify download
    if (-not (Test-Path $tempFile) -or (Get-Item $tempFile).Length -eq 0) {
      throw "Download failed or resulted in empty file"
    }
    
    # Calculate checksum
    Write-Log "Calculating SHA256 checksum..." "Info"
    $checksum = Get-FileHash -Path $tempFile -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    Write-Log "SHA256: $checksum" "Success"
    
    # Backup current files
    $backupDir = Join-Path $PSScriptRoot "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
    
    Copy-Item $nuspecPath -Destination $backupDir
    Copy-Item (Join-Path $PSScriptRoot 'tools\chocolateyinstall.ps1') -Destination $backupDir
    
    Write-Log "Created backup in $backupDir" "Info"
    
    # Update nuspec version
    $nuspec.package.metadata.version = $latestVersion
    $nuspec.Save($nuspecPath)
    Write-Log "Updated nuspec to version $latestVersion" "Success"
    
    # Update checksum in chocolateyinstall.ps1
    $installScriptPath = Join-Path $PSScriptRoot 'tools\chocolateyinstall.ps1'
    $installScript = Get-Content $installScriptPath -Raw
    
    # Replace the checksum (looking for either PLACEHOLDER_CHECKSUM or an actual checksum)
    $installScript = $installScript -replace "checksum64\s*=\s*'([A-F0-9]{64}|PLACEHOLDER_CHECKSUM)'", "checksum64     = '$checksum'"
    
    Set-Content -Path $installScriptPath -Value $installScript -NoNewline
    Write-Log "Updated checksum in chocolateyinstall.ps1" "Success"
    
    # Auto-commit if requested
    if ($AutoCommit) {
      Write-Log "Creating git commit..." "Info"
      git add $nuspecPath $installScriptPath $verificationPath 2>$null
      git commit -m "Update OpenCode to v$latestVersion" -m "- Updated version from $currentVersion to $latestVersion" -m "- Updated SHA256 checksum: $checksum" 2>$null
      Write-Log "Changes committed to git" "Success"
    }
    
    Write-Log "`nPackage updated successfully!" "Success"
    Write-Log "Next steps:" "Info"
    Write-Log "  1. Review the changes" "Info"
    Write-Log "  2. Run 'choco pack' to create the package" "Info"
    Write-Log "  3. Test locally with 'choco install opencode -dvy -s . --force'" "Info"
    Write-Log "  4. Push to Chocolatey with 'choco push opencode.$latestVersion.nupkg'" "Info"
    
    # Clean up backup if everything succeeded
    if (Test-Path $backupDir) {
      Remove-Item $backupDir -Recurse -Force
    }
    
  }
  catch {
    Write-Log "Error during update: $_" "Error"
    
    # Restore from backup if it exists
    if ($backupDir -and (Test-Path $backupDir)) {
      Write-Log "Restoring from backup..." "Warning"
      Copy-Item "$backupDir\*" -Destination $PSScriptRoot -Force
      Write-Log "Files restored from backup" "Info"
    }
    
    throw
  }
  finally {
    # Clean up temp file
    if (Test-Path $tempFile) {
      Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    }
    
    # Clean up web client
    if ($webClient) {
      $webClient.Dispose()
    }
  }
  
}
catch {
  Write-Log $_.Exception.Message "Error"
  exit 1
}