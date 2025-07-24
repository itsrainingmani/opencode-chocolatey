# Automated release script for opencode Chocolatey package
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    
    [string]$CommitMessage,
    [string]$ReleaseNotes,
    [switch]$DryRun,
    [switch]$SkipTests,
    [switch]$Force
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

function Test-GitStatus {
    $gitStatus = git status --porcelain 2>$null
    if ($gitStatus -and -not $Force) {
        Write-Log "Working directory has uncommitted changes. Use -Force to proceed anyway." "Error"
        Write-Log "Uncommitted files:" "Warning"
        $gitStatus | ForEach-Object { Write-Log "  $_" "Warning" }
        exit 1
    }
}

function Test-Prerequisites {
    # Check if we're in a git repository
    if (-not (Test-Path '.git')) {
        Write-Log "Not in a git repository root directory" "Error"
        exit 1
    }
    
    # Check if git is available
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Log "Git is not installed or not in PATH" "Error"
        exit 1
    }
    
    # Check if choco is available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Log "Chocolatey is not installed or not in PATH" "Error"
        exit 1
    }
    
    # Check if GitHub CLI is available (optional but recommended)
    $ghAvailable = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $ghAvailable) {
        Write-Log "GitHub CLI (gh) not found. Release will need to be created manually." "Warning"
    }
    
    return $null -ne $ghAvailable
}

function Get-CurrentVersion {
    $nuspecPath = 'opencode.nuspec'
    if (-not (Test-Path $nuspecPath)) {
        Write-Log "opencode.nuspec not found" "Error"
        exit 1
    }
    
    $nuspec = [xml](Get-Content $nuspecPath)
    return $nuspec.package.metadata.version
}

function Test-PackageLocally {
    Write-Log "Testing package locally..." "Info"
    
    try {
        # Pack the package
        $packResult = choco pack --yes 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Choco pack failed: $packResult"
        }
        
        # Test installation
        $installResult = choco install opencode -dy --source="'.,https://community.chocolatey.org/api/v2/'" --force 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Choco install failed: $installResult"
        }
        
        # Test that opencode runs
        $versionResult = opencode --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "opencode --version failed: $versionResult"
        }
        
        Write-Log "Package test successful. Version: $versionResult" "Success"
        
        # Uninstall test package
        choco uninstall opencode -y 2>&1 | Out-Null
        
    }
    catch {
        Write-Log "Package testing failed: $_" "Error"
        exit 1
    }
}

function New-GitHubRelease {
    param(
        [string]$TagName,
        [string]$Title,
        [string]$Notes,
        [string]$PackageFile
    )
    
    try {
        $packageArgs = @(
            'release', 'create', $TagName,
            '--title', $Title,
            '--notes', $Notes
        )
        
        if ($PackageFile -and (Test-Path $PackageFile)) {
            $packageArgs += $PackageFile
        }
        
        Write-Log "Creating GitHub release..." "Info"
        & gh @packageArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "GitHub release created successfully" "Success"
            return $true
        }
        else {
            Write-Log "GitHub release creation failed" "Warning"
            return $false
        }
    }
    catch {
        Write-Log "GitHub release creation failed: $_" "Warning"
        return $false
    }
}

try {
    Write-Log "Starting automated release process for version $Version" "Info"
    
    if ($DryRun) {
        Write-Log "DRY RUN MODE - No changes will be made" "Warning"
    }
    
    # Check prerequisites
    $hasGitHub = Test-Prerequisites
    
    # Check git status
    Test-GitStatus
    
    # Get current version
    $currentVersion = Get-CurrentVersion
    Write-Log "Current version: $currentVersion" "Info"
    Write-Log "Target version: $Version" "Info"
    
    if ($currentVersion -eq $Version -and -not $Force) {
        Write-Log "Version $Version is already current. Use -Force to proceed anyway." "Warning"
        exit 0
    }
    
    if ($DryRun) {
        Write-Log "Would update from $currentVersion to $Version" "Info"
        Write-Log "Would create commit, tag, and release" "Info"
        exit 0
    }
    
    # Run update script with specific version
    Write-Log "Running update script for version $Version..." "Info"
    & .\update.ps1 -SpecificVersion $Version -AutoCommit:$false
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Update script failed" "Error"
        exit 1
    }
    
    # Test package locally if not skipped
    if (-not $SkipTests) {
        Test-PackageLocally
    }
    
    # Prepare commit message
    $finalCommitMessage = if ($CommitMessage) { 
        $CommitMessage 
    }
    else { 
        "Release opencode v$Version"
    }
    
    # Create git commit
    Write-Log "Creating git commit..." "Info"
    git add opencode.nuspec tools/chocolateyinstall.ps1
    git commit -m $finalCommitMessage -m "- Updated from version $currentVersion to $Version" -m "- Updated checksums and release notes"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Git commit failed" "Error"
        exit 1
    }
    
    # Create and push tag
    $tagName = "v$Version"
    Write-Log "Creating tag $tagName..." "Info"
    git tag -a $tagName -m "Release $tagName"
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Tag creation failed" "Error"
        exit 1
    }
    
    Write-Log "Pushing changes and tag..." "Info"
    git push origin main
    git push origin $tagName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Push failed" "Error"
        exit 1
    }
    
    # Create package file for release
    $packageFile = "opencode.$Version.nupkg"
    if (-not (Test-Path $packageFile)) {
        Write-Log "Package file $packageFile not found, creating..." "Info"
        choco pack --yes
    }
    
    # Create GitHub release if GitHub CLI is available
    if ($hasGitHub) {
        $releaseTitle = "opencode v$Version"
        $finalReleaseNotes = if ($ReleaseNotes) {
            $ReleaseNotes
        }
        else {
            @"
# opencode Chocolatey Package v$Version

Updated opencode from v$currentVersion to v$Version.

## Changes
- Updated package version to $Version
- Updated SHA256 checksums
- Updated release notes URL

## Installation
``````
choco install opencode
``````

## Upgrade
``````
choco upgrade opencode
``````
"@
        }
        
        $releaseCreated = New-GitHubRelease -TagName $tagName -Title $releaseTitle -Notes $finalReleaseNotes -PackageFile $packageFile
        
        if (-not $releaseCreated) {
            Write-Log "Manual release creation required at: https://github.com/itsrainingmani/opencode-chocolatey/releases/new?tag=$tagName" "Info"
        }
    }
    else {
        Write-Log "GitHub CLI not available. Create release manually at:" "Info"
        Write-Log "https://github.com/itsrainingmani/opencode-chocolatey/releases/new?tag=$tagName" "Info"
    }
    
    Write-Log "`nRelease process completed successfully!" "Success"
    Write-Log "Version: $Version" "Info"
    Write-Log "Tag: $tagName" "Info"
    Write-Log "Package: $packageFile" "Info"
    
    Write-Log "`nNext steps:" "Info"
    Write-Log "1. Verify the GitHub release was created properly" "Info"
    Write-Log "2. Push to Chocolatey Community with: choco push $packageFile --source https://push.chocolatey.org/" "Info"
    Write-Log "3. Monitor the package approval process" "Info"
    
}
catch {
    Write-Log "Release process failed: $_" "Error"
    Write-Log "You may need to clean up any partial changes manually" "Warning"
    exit 1
}
