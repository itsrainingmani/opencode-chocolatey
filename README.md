# Chocolatey opencode

This is a **Chocolatey package** repository for distributing [sst/opencode](https://github.com/sst/opencode) on Windows

## Commands

```powershell
# Update package to latest version (fetches checksums automatically)
.\update.ps1

# Check for updates without applying them
.\update.ps1 -CheckOnly

# Build the package
choco pack

# Test installation locally
choco install opencode -dvy -s .

# Test the installed application
opencode --version

# Test uninstallation
choco uninstall opencode -dvy

# Run test suite
.\test-package.ps1 -Verbose
```

### Publishing to Chocolatey Community Repository

```powershell
# Set API key (get from https://community.chocolatey.org/account)
choco apikey -k YOUR_API_KEY_HERE -s https://push.chocolatey.org/

# Push the package
choco push opencode.X.X.X.nupkg -s https://push.chocolatey.org/
```
