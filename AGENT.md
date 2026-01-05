# OpenCode Chocolatey Package - Agent Guide

## Commands

- **Test package**: `.\test-package.ps1` (comprehensive test suite with installation/uninstallation)
- **Update package**: `.\update.ps1` (downloads latest opencode release and updates nuspec/checksum)
- **Check for updates**: `.\update.ps1 -CheckOnly` (exit codes: 0=up-to-date, 1=update available, 2=no Win64 asset)
- **Build package**: `choco pack` (creates .nupkg file)
- **Local install test**: `choco install opencode -dy --source="'.,https://community.chocolatey.org/api/v2/'"`
- **Publish**: `choco push opencode.X.X.X.nupkg -s https://push.chocolatey.org/`

## Architecture

This is a Windows Chocolatey package for distributing [anomalyco/opencode](https://github.com/anomalyco/opencode), an AI coding terminal agent. The package automatically downloads the Windows x64 binary from GitHub releases and installs it to the Chocolatey tools directory.

**Key files:**

- `opencode.nuspec` - Package metadata (version, dependencies: unzip, ripgrep, fzf)
- `tools/chocolateyinstall.ps1` - Downloads zip, extracts opencode.exe, installs to PATH
- `tools/chocolateyuninstall.ps1` - Removes binary file
- `update.ps1` - Updates package version and SHA256 checksum from GitHub releases
- `.github/workflows/auto-update.yml` - Runs every 1 hour, creates PRs for new versions

## Code Style

- PowerShell scripts use `$ErrorActionPreference = 'Stop'` for strict error handling
- Checksum validation is mandatory (SHA256) - never use placeholder values
- Use proper error handling with try/catch blocks and exit codes
- XML manipulation for nuspec files using `[xml]` casting
- GitHub API calls include User-Agent headers and retry logic
