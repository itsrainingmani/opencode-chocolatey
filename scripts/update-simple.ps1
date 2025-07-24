# Simplified update script for manual use
param(
    [switch]$CheckOnly,
    [string]$Version
)

$ErrorActionPreference = 'Stop'

function Write-Status {
    param([string]$Message, [string]$Type = 'Info')
    $color = switch ($Type) {
        'Error' { 'Red' }
        'Success' { 'Green' }
        'Warning' { 'Yellow' }
        default { 'Cyan' }
    }
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

try {
    # Get current version
    [xml]$nuspec = Get-Content 'opencode.nuspec'
    $currentVersion = $nuspec.package.metadata.version
    Write-Status "Current version: $currentVersion"

    # Get target version
    if ($Version) {
        $targetVersion = $Version
        $apiUrl = "https://api.github.com/repos/sst/opencode/releases/tags/v$Version"
    } else {
        $apiUrl = 'https://api.github.com/repos/sst/opencode/releases/latest'
    }

    $headers = @{ 
        'User-Agent' = 'opencode-chocolatey-updater'
        'Accept' = 'application/vnd.github.v3+json'
    }

    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    $targetVersion = $release.tag_name.TrimStart('v')
    Write-Status "Target version: $targetVersion"

    # Check if update needed
    if ($currentVersion -eq $targetVersion) {
        Write-Status "Already up to date!" "Success"
        if ($CheckOnly) { exit 0 }
        return
    }

    # Find Windows asset
    $asset = $release.assets | Where-Object { $_.name -eq 'opencode-windows-x64.zip' }
    if (-not $asset) {
        Write-Status "Windows x64 asset not available" "Error"
        if ($CheckOnly) { exit 2 }
        throw "Windows asset not found"
    }

    if ($CheckOnly) {
        Write-Status "Update available: $currentVersion -> $targetVersion" "Warning"
        exit 1
    }

    # Download and get checksum
    Write-Status "Downloading release..."
    $tempFile = Join-Path $env:TEMP "opencode-$targetVersion.zip"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -UserAgent 'opencode-chocolatey-updater'
    
    $checksum = Get-FileHash -Path $tempFile -Algorithm SHA256 | Select-Object -ExpandProperty Hash
    Write-Status "Checksum: $checksum"

    # Update files
    Write-Status "Updating package files..."
    
    # Update nuspec
    $nuspec.package.metadata.version = $targetVersion
    $nuspec.package.metadata.releaseNotes = "https://github.com/sst/opencode/releases/tag/v$targetVersion"
    $nuspec.Save('opencode.nuspec')

    # Update install script
    $installScript = Get-Content 'tools\chocolateyinstall.ps1' -Raw
    $installScript = $installScript -replace "checksum64\s*=\s*'[A-F0-9]{64}'", "checksum64     = '$checksum'"
    Set-Content -Path 'tools\chocolateyinstall.ps1' -Value $installScript -NoNewline

    Write-Status "Package updated to version $targetVersion!" "Success"
    Write-Status "Run 'choco pack' to build the package"

    # Cleanup
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Status "Error: $_" "Error"
    exit 1
}
