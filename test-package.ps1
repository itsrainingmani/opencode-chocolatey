# Comprehensive test suite for the opencode Chocolatey package
param(
  [switch]$SkipUninstall,
  [switch]$Verbose
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }

function Test-Command {
  param([string]$Command)
  $null = Get-Command $Command -ErrorAction SilentlyContinue
  return $?
}

function Write-TestResult {
  param(
    [string]$Test,
    [bool]$Passed,
    [string]$Details = ""
  )
  
  $symbol = if ($Passed) { "[PASS]" } else { "[FAIL]" }
  $color = if ($Passed) { "Green" } else { "Red" }
  
  Write-Host "$symbol $Test" -ForegroundColor $color
  if ($Details -and (-not $Passed -or $Verbose)) {
    Write-Host "       $Details" -ForegroundColor Gray
  }
}

Write-Host "`nopencode Chocolatey Package Test Suite" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# Test 1: Package file exists
$nuspecPath = Join-Path $PSScriptRoot 'opencode.nuspec'
$packageExists = Test-Path $nuspecPath
Write-TestResult "Package specification exists" $packageExists

if (-not $packageExists) {
  Write-Host "`nCritical error: opencode.nuspec not found" -ForegroundColor Red
  exit 1
}

# Test 2: Valid nuspec
try {
  $nuspec = [xml](Get-Content $nuspecPath)
  $version = $nuspec.package.metadata.version
  $validNuspec = $true
  Write-TestResult "Valid nuspec file" $validNuspec "Version: $version"
}
catch {
  Write-TestResult "Valid nuspec file" $false $_.Exception.Message
  exit 1
}

# Test 3: Checksum is not placeholder
$installScript = Get-Content (Join-Path $PSScriptRoot 'tools\chocolateyinstall.ps1') -Raw
$hasPlaceholder = $installScript -match 'PLACEHOLDER_CHECKSUM'
Write-TestResult "Checksum is set (not placeholder)" (-not $hasPlaceholder)

if ($hasPlaceholder) {
  Write-Host "`nRun .\update.ps1 to set the checksum" -ForegroundColor Yellow
}

# Test 4: Required files exist
$requiredFiles = @(
  'tools\chocolateyinstall.ps1',
  'tools\chocolateyuninstall.ps1'
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
  $filePath = Join-Path $PSScriptRoot $file
  $exists = Test-Path $filePath
  if (-not $exists) {
    $allFilesExist = $false
    Write-Verbose "Missing: $file"
  }
}
Write-TestResult "All required files exist" $allFilesExist

# Test 5: Pack the package
Write-Host "`nPacking package..." -ForegroundColor Yellow
try {
  $output = choco pack 2>&1
  $packSuccess = $LASTEXITCODE -eq 0
  $packageFile = Get-ChildItem -Path $PSScriptRoot -Filter "opencode.$version.nupkg" | Select-Object -First 1
  
  Write-TestResult "Package creation" $packSuccess
  if ($packageFile) {
    Write-Verbose "Created: $($packageFile.Name) ($('{0:N2} MB' -f ($packageFile.Length / 1MB)))"
  }
}
catch {
  Write-TestResult "Package creation" $false $_.Exception.Message
  exit 1
}

# Test 6: Install the package
Write-Host "`nInstalling package..." -ForegroundColor Yellow
try {
  # First uninstall if already installed
  if (Test-Command 'opencode.exe') {
    Write-Verbose "Uninstalling existing installation..."
    choco uninstall opencode -y --force 2>&1 | Out-Null
  }
  
  $installOutput = choco install opencode -dvy -s . --force 2>&1
  $installSuccess = $LASTEXITCODE -eq 0
  
  Write-TestResult "Package installation" $installSuccess
  
  if (-not $installSuccess) {
    $errors = $installOutput | Where-Object { $_ -match 'ERROR|FATAL' }
    foreach ($err in $errors) {
      Write-Verbose "  $err"
    }
  }
}
catch {
  Write-TestResult "Package installation" $false $_.Exception.Message
}

# Test 7: Verify installation
$commandExists = Test-Command 'opencode.exe'
Write-TestResult "opencode command available" $commandExists

# Test 8: Version check
if ($commandExists) {
  try {
    $installedVersion = & opencode --version 2>&1
    $versionMatches = $installedVersion -match $version
    Write-TestResult "Version verification" $versionMatches "Expected: $version, Got: $installedVersion"
  }
  catch {
    Write-TestResult "Version verification" $false $_.Exception.Message
  }
}

# Test 9: PATH verification
$inPath = $env:PATH -split ';' | Where-Object { $_ -match 'chocolatey\\bin' }
Write-TestResult "Chocolatey bin in PATH" ($null -ne $inPath)

# Test 10: Uninstall test
if (-not $SkipUninstall -and $commandExists) {
  Write-Host "`nTesting uninstallation..." -ForegroundColor Yellow
  try {
    choco uninstall opencode -y 2>&1
    $uninstallSuccess = $LASTEXITCODE -eq 0
    
    # Verify removal
    $stillExists = Test-Command 'opencode.exe'
    $cleanUninstall = $uninstallSuccess -and (-not $stillExists)
    
    Write-TestResult "Package uninstallation" $cleanUninstall
  }
  catch {
    Write-TestResult "Package uninstallation" $false $_.Exception.Message
  }
}

# Test 10: Update script exists and is executable
$updateScriptPath = Join-Path $PSScriptRoot 'update.ps1'
$updateScriptExists = Test-Path $updateScriptPath
Write-TestResult "Update script exists" $updateScriptExists

# Summary
Write-Host "`nTest Summary" -ForegroundColor Cyan
Write-Host "============" -ForegroundColor Cyan

$totalTests = 10
$passedTests = @(
  $packageExists,
  $validNuspec,
  (-not $hasPlaceholder),
  $allFilesExist,
  $packSuccess,
  $installSuccess,
  $commandExists,
  $versionMatches,
  $cleanUninstall,
  $updateScriptExists
) | Where-Object { $_ -eq $true } | Measure-Object | Select-Object -ExpandProperty Count

$allPassed = $passedTests -eq $totalTests

Write-Host "Passed: $passedTests/$totalTests" -ForegroundColor $(if ($allPassed) { "Green" } else { "Yellow" })

if (-not $allPassed) {
  Write-Host "`nSome tests failed. Review the output above for details." -ForegroundColor Yellow
  exit 1
}
else {
  Write-Host "`nAll tests passed!" -ForegroundColor Green
  exit 0
}