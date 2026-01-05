# Chocolatey opencode

![Chocolatey Version](https://img.shields.io/chocolatey/v/opencode) ![Chocolatey Downloads](https://img.shields.io/chocolatey/dt/opencode?style=plastic) ![Vibe Coded](https://img.shields.io/badge/vibe_coded-100%25-green?logo=claude) ![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/itsrainingmani/opencode-chocolatey/auto-release.yml)

This is a [**Chocolatey Community Package**](https://community.chocolatey.org/) repository for packaging & distributing [anomalyco/opencode](https://github.com/anomalyco/opencode) on Windows

## Automatic Package Release

This package runs a github action every [30 minutes](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#schedule) to check if [anomalyco/opencode](https://github.com/anomalyco/opencode) has a new release. If so, the release is downloaded, packaged, tested & published to Chocolatey.

## Commands

```powershell
# Update package to latest version (fetches checksums automatically)
.\update.ps1

# Check for updates without applying them
.\update.ps1 -CheckOnly

# Build the package
choco pack

# Test installation locally (while downloading dependencies from chocolatey)
choco install opencode -dy --source="'.,https://community.chocolatey.org/api/v2/'"

# Test the installed application
opencode --version

# Test uninstallation
choco uninstall opencode -dvy

# Run test suite
.\test-package.ps1 -Verbose

# Release a version manually
.\release.ps1 -Version "x.y.zz"
```

### Publishing to Chocolatey Community Repository

```powershell
# Set API key (get from https://community.chocolatey.org/account)
choco apikey -k YOUR_API_KEY_HERE -s https://push.chocolatey.org/

# Push the package
choco push opencode.X.X.X.nupkg -s https://push.chocolatey.org/
```

## Feedback

Please feel free to contribute to this repo! I do not have much experience with writing Chocolatey packages, PowerShell scripting or release management. Almost 100% of this repo was built with auspices of Sonnet 4 in opencode & AmpCode.

You can also leave feedback for this package in the comments section of the [package](https://community.chocolatey.org/packages/opencode)


## Links

- [opencode on chocolatey](https://community.chocolatey.org/packages/opencode)
- [opencode.ai](https://opencode.ai)
- [github/anomalyco/opencode](https://github.com/anomalyco/opencode)
- [opencode releases](https://github.com/anomalyco/opencode/releases)
