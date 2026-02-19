# Full Project Code Review: Sharp Ninja's PowerShell Snippets

**Review Date:** 2026-02-19
**Repository:** PS-Services/Snippets
**Reviewer:** Copilot

---

## Overview

A collection of PowerShell profile tools providing: unified package manager abstraction (13+ managers), Bing search, Oh-My-Posh setup, GitHub folder navigation, VS dev mode, Chocolatey integration, module auto-loading from YAML, and profile update tooling. Supports Windows, Linux, WSL, and macOS.

---

## Critical Issues

### C1: Bing API Key Hardcoded in Source

**File:** `bing.ps1:33`
**Severity:** Critical (Security)

```powershell
$ApiKey = '3c7e251544ba414cbeacad9db55bdf6e'
```

A Bing API subscription key is committed in plaintext. This key is visible to anyone who clones the repo. It should be stored in an environment variable, secrets file, or credential manager — never in source control.

**Suggested fix:** Remove the hardcoded key and require `$env:BingApiKey` to be set externally (e.g., in `~/.ssh/secrets.ps1` which is already sourced by the user's profile).

---

### C2: GitHub Actions Workflow Uses Deprecated `set-output` Syntax

**File:** `.github/workflows/manual.yml:38`
**Severity:** Critical (CI/CD broken)

```yaml
echo "::set-output name=version::$version"
```

`set-output` was deprecated in October 2022 and removed. This workflow will fail silently.

**Fix:** Replace with:
```yaml
echo "version=$version" >> "$GITHUB_OUTPUT"
```

---

### C3: GitHub Actions Workflow Pushes with Hardcoded Username

**File:** `.github/workflows/manual.yml:43`
**Severity:** High (Security/Maintenance)

```yaml
git push --repo='https://sharpninja:${{ secrets.GITHUB_TOKEN }}@github.com/sharpninja/Snippets.git'
```

Embeds the GitHub username in the push URL. The repo is now under `PS-Services` org, but this still references `sharpninja/Snippets`. Also uses `actions/checkout@v1` (line 19) — severely outdated.

---

## High Severity Issues

### H1: `_common.ps1` Has Stale Debug Text in Verbose Output

**File:** `_common.ps1:90`

```powershell
Write-Verbose "[$script] [$env:Snippetscode Initialized] -not ..."
```

`$env:Snippetscode` is a typo — should be `$env:SnippetsInitialized`. This produces confusing debug output.

---

### H2: `github.ps1` Recursively Searches Entire Drive for `github` Folder

**File:** `github.ps1:23`

```powershell
$env:GITHUB = (Get-ChildItem -Filter github -Path $hintPath -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
```

On Windows, `$hintPath = "C:\"`. This recursively scans the entire C: drive, which can take minutes and consume significant I/O. On Linux, `$hintPath = "~"` which is slightly better but still potentially slow.

**Suggested fix:** Search only common locations (e.g., `$env:USERPROFILE`, `$env:HOME`) or require `$env:GITHUB` to be set explicitly.

---

### H3: `oh-my-posh-linux.ps1` Downloads Binary with `sudo wget` Without Checksum Verification

**File:** `oh-my-posh-linux.ps1:27`

```powershell
$log = @(sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O /usr/local/bin/oh-my-posh)
```

Downloads an executable directly into `/usr/local/bin` with root privileges and no integrity check. A MITM attack could inject malicious code. The official install method is now `curl -s https://ohmyposh.dev/install.sh | bash`.

---

### H4: `linux-setup.sh` Downloads Outdated .NET SDK

**File:** `linux-setup.sh:70-72`

```bash
url="https://download.visualstudio.microsoft.com/download/.../dotnet-sdk-7.0.101-linux-x64.tar.gz";
curl -o dotnet-sdk-6.0.100-linux-x64.tar.gz --verbose $url;
```

URL says 7.0.101 but output filename says 6.0.100. Both are EOL. .NET 8 or 9 should be used. The mismatched filename also means the subsequent `tar` extraction references the wrong file.

---

### H5: Module Auto-Loader — `powershell-yaml` Failure Breaks All Module Loading

**File:** `module-loader.ps1:20-26`

`Install-YamlModuleIfMissing` uses `-ErrorAction Stop`. If PSGallery is unreachable (network down, corporate firewall), the entire module auto-loader fails and no modules load.

**Suggested fix:** Return a boolean and degrade gracefully:
```powershell
if (-not (Install-YamlModuleIfMissing -Verbose:$Verbose)) {
    return "Module auto-loader disabled: powershell-yaml unavailable."
}
```

---

## Medium Severity Issues

### M1: `set-version.ps1` Auto-Commits Without User Consent

**File:** `set-version.ps1:38-48`

```powershell
git add $versionFilePath
git commit -m "Added version"
```

If `.version` doesn't exist, the script creates it, stages it, and commits — with no confirmation. This can pollute git history and surprise users who dot-source this file during profile loading.

---

### M2: Duplicate `$env:POSH_GIT_ENABLED` in User Profile

**File:** `Microsoft.PowerShell_profile.ps1:8, 14`

```powershell
$env:POSH_GIT_ENABLED = $true   # line 8
...
$env:POSH_GIT_ENABLED = $true   # line 14
```

Set twice — minor but indicates copy-paste drift.

---

### M3: `_repos.ps1` Hardcodes Module Filename in `Get-ChildItem`

**File:** `_repos.ps1:9`

```powershell
$packageManagers = Get-ChildItem SnippetsManager.psm1 -Path $env:Snippets
```

Uses positional parameter ambiguously. `Get-ChildItem` interprets the first positional as `-Path` and `-Path` as a second path. Should be:
```powershell
$packageManagers = Get-ChildItem -Path (Join-Path $env:Snippets 'SnippetsManager.psm1')
```

---

### M4: `[Version]` Cast in `module-loader.ps1` Doesn't Handle SemVer Pre-Release

**File:** `module-loader.ps1:83, 99`

`[Version]"1.0.0-beta"` throws. Users following common SemVer conventions will hit confusing errors. Use `[Version]::TryParse()` with a fallback.

---

### M5: `Reload-SnippetsModule` Single-Module Mode Fails for Path-Based Modules

**File:** `module-loader.ps1:167-172`

```powershell
Import-Module -Name $ModuleName -Force
```

Path-based modules (e.g., `MsixTools` loaded from `E:\github\...`) aren't in PSModulePath. Reload by name will fail. Only `modrl` (all) works for path-based modules.

---

### M6: `PSGalleryManager.Execute` — `Uninstall-PSResource -Scope CurrentUser` Invalid

**File:** `SnippetsManager.psm1:1309`

`Uninstall-PSResource` doesn't accept `-Scope`. Remove the parameter.

---

### M7: Concurrent Profile Loads Can Race on `Install-Module`

**File:** `module-loader.ps1:111-124`

Multiple terminal tabs opening simultaneously may all try to `Install-Module` the same package, causing file lock errors. Add retry logic or a lock file check.

---

### M8: `oh-my-posh-windows.ps1` Uses `pwsh` for Both Core and Desktop

**File:** `oh-my-posh-windows.ps1:20-25`

```powershell
if ($PSVersionTable.PSEdition -ieq 'core') {
    $powershell = 'pwsh'
} else {
    $powershell = 'pwsh'   # Should be 'powershell'
}
```

Both branches set `$powershell = 'pwsh'`. The Desktop branch should use `'powershell'`.

---

## Low Severity Issues

### L1: `oh-my-posh` Init Uses Deprecated `--init` Flag

**Files:** `oh-my-posh-windows.ps1:47`, `oh-my-posh-linux.ps1:45`, `oh-my-posh-macos.ps1:44`

```powershell
oh-my-posh --init --shell pwsh --config "..." | Invoke-Expression
```

Modern oh-my-posh uses `oh-my-posh init pwsh --config "..." | Invoke-Expression`.

---

### L2: GitHub Actions Uses Outdated Action Versions

**File:** `.github/workflows/jekyll-gh-pages.yml`

- `actions/checkout@v3` → current is v4
- `actions/configure-pages@v3` → current is v5
- `actions/upload-pages-artifact@v1` → current is v4
- `actions/deploy-pages@v2` → current is v4

**File:** `.github/workflows/manual.yml`

- `actions/checkout@v1` → current is v4
- `Elskom/setup-latest-dotnet@v1` — may be unmaintained
- `marvinpinto/action-automatic-releases@latest` — archived repo

---

### L3: `ReadmeTest.ps9` Files Don't Use `$env:SnippetsModulesYaml`

**Files:** `Windows-ReadmeTest.ps9`, `Linux-ReadmeTest.ps9`

These template files are used by `Update-Profile` to replace the SNIPPETS block in `$PROFILE`, but neither includes `$env:SnippetsModulesYaml`. Running `snipup` will overwrite users' profile without the YAML override, breaking module auto-loading from custom paths.

---

### L4: `update-snippets.ps1` Sets `$env:Snippets` Unconditionally

**File:** `update-snippets.ps1:17-22`

```powershell
if ($env:IsWindows -ieq 'true') {
    $env:Snippets = "$env:OneDrive\Documents\PowerShell\Snippets"
} else {
    $env:Snippets = "$env:HOME/.config/powershell/Snippets"
}
```

Overwrites any user-customized `$env:Snippets` path every time this snippet loads.

---

### L5: `Execute-OMP` References Unscoped `$Verbose`

**Files:** `oh-my-posh-windows.ps1:67`, `oh-my-posh-linux.ps1:71`

```powershell
$result = Invoke-Command -Verbose:$Verbose -ScriptBlock $scriptBlock -ArgumentList $args
```

`$Verbose` is not a parameter of `Execute-OMP` — it references the script-level variable which may have been reset to `$VerboseSwitch` in the `finally` block.

---

### L6: `clean-folder.ps1` Uses Unapproved Verb `Clean`

**File:** `clean-folder.ps1:15`

`Clean-Folder` uses the unapproved verb `Clean`. PowerShell best practice uses `Clear-*` or `Remove-*`. This triggers warnings with `Import-Module -Verbose`.

---

### L7: `.gitignore` Missing Common Entries

**File:** `.gitignore`

Missing entries for: `.version`, `*.bak`, `_site/` output files, and OS artifacts (`Thumbs.db`, `.DS_Store`). The `_site` entry exists but `ninja.omp.json.bak` is tracked as untracked.

---

### L8: `GitVersion.yml` — `next-version: 1.1.0` May Be Outdated

**File:** `GitVersion.yml:2`

Current SemVer is `1.2.1-ci.57` but `next-version` is still `1.1.0`. This field only affects versions calculated before the first tag, so it's likely inert, but could confuse contributors.

---

### L9: `PSGalleryManager` Returns `-RequiredVersion` Instead of `-MinimumVersion`

**File:** `SnippetsManager.psm1:1366`

```powershell
$inst = "Install-Module $id -RequiredVersion $ver -Scope CurrentUser"
```

README documents `version` as "Minimum required version" but the generated install command uses `-RequiredVersion` (exact match). Should use `-MinimumVersion`.

---

### L10: `modules.yml` Default Config Only Has `powershell-yaml`

**File:** `modules.yml`

The default config ships with only `powershell-yaml`. All other entries are commented out. This is correct for the repo default, but could include a comment pointing users to `$env:SnippetsModulesYaml` for customization (already in README, but inline help is useful).

---

### L11: `_common.ps1` — `Initialize-Snippets` Uses `Join-Path` with `-Child` Instead of `-ChildPath`

**File:** `_common.ps1:59`

```powershell
$versionFilePath = Join-Path (Get-Location) -Child ".version"
```

`-Child` is an alias for `-ChildPath` and works, but is inconsistent with `-ChildPath` used elsewhere in the codebase.

---

## Documentation Issues

### D1: README Scripts Table Missing `oh-my-posh-macos.ps1`

The macOS variant is not listed in the scripts compatibility table.

### D2: README Repos Section Lists `wq` for WinGet

**File:** `README.md:209`

```markdown
- `wq` winget
```

The actual alias is `wg`, not `wq`.

### D3: `linux-setup.sh` URL in README Uses `master` Branch

**File:** `README.md:24`

```markdown
curl 'https://raw.githubusercontent.com/PS-Services/Snippets/master/linux-setup.sh'
```

The repo appears to use `master`, so this is correct, but the script itself is outdated (see H4).

---

## Architecture Observations (Non-Issues)

### Pattern Consistency ✅
All snippets follow the `param([switch]$VerboseSwitch)` / `Initialize-Snippets` / try-catch-finally pattern consistently. New files (`module-loader.ps1`) follow this pattern.

### Module Architecture ✅
`SnippetsManager.psm1` uses proper class inheritance for 14 package managers. The `PackageManager` base class with `Execute`/`ParseResults`/`ParseResultItem` virtual pattern is well-structured. `PSGalleryManager`'s `Execute` override is the right approach for cmdlet-based managers.

### Cross-Platform Support ✅
OS detection via `$env:IsWindows`/`$env:IsUnix` is consistent. Windows/Linux/macOS each have appropriate scripts and the Invoke-All/Invoke-AllLinux split is clean.

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 3 (C1, C2, C3) |
| High | 5 (H1–H5) |
| Medium | 8 (M1–M8) |
| Low | 11 (L1–L11) |
| Documentation | 3 (D1–D3) |
| **Total** | **30** |

### Priority Recommendations

1. **Immediately:** Remove hardcoded Bing API key (C1)
2. **High priority:** Fix GitHub Actions workflows (C2, C3), outdated `linux-setup.sh` (H4), drive-scanning in `github.ps1` (H2)
3. **Before next release:** Fix `oh-my-posh` deprecated flags (L1, M8), add graceful degradation to module-loader (H5), fix `ReadmeTest.ps9` templates (L3)
4. **Cleanup pass:** Update Action versions (L2), fix `wq` → `wg` in README (D2), add macOS to scripts table (D1)
