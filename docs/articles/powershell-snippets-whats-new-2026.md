# PowerShell Snippets: What's New in 2026

*A follow-up to [Repo Like a Pro](https://medium.com/the-unpopular-opinions-of-a-senior-developer/powershell-snippets-repo-like-a-pro-84eb266f64b8)*

[github.com/ps-services/snippets](https://github.com/PS-Services/Snippets)

---

Back in September 2023 I wrote about the unified repository system in PowerShell Snippets — how you can use short aliases like `wg`, `scp`, and `ch` to search, install, and manage packages across a dozen package managers with a single consistent interface. If you missed it, go [read that one first](https://medium.com/the-unpopular-opinions-of-a-senior-developer/powershell-snippets-repo-like-a-pro-84eb266f64b8?sk=5b42fce533a7cd9010a12406ee6499d3). I'll wait.

Since then, snipps has picked up three features that I now can't live without: **declarative module auto-loading from YAML**, a **PSGallery package manager**, and a **module reload alias**. Let me walk you through each one.

---

## Declarative Module Loading with YAML

Here's a question: how many `Import-Module` lines are in your `$PROFILE`? If you're anything like me, the answer used to be "too many, and I don't remember why half of them are there."

I wanted something declarative. Something I could look at and immediately understand what modules my shell needs, where they come from, and whether they're critical or optional. So I built a YAML-based module auto-loader.

### How It Works

Drop a `modules.yml` file in your home folder:

```yaml
modules:
  - name: powershell-yaml
    required: true

  - name: WingetTools
    version: "1.7.0"

  - name: posh-git
    required: false

  - name: Terminal-Icons
    required: false
    version: "0.11.0"

  - name: MsixTools
    source: "E:\\github\\remote-agent\\scripts\\MsixTools\\MsixTools.psd1"
    required: false
```

Then point snipps at it in your `$PROFILE`:

```powershell
$env:SnippetsModulesYaml = "$env:USERPROFILE\modules.yml"
```

That's it. On startup, snipps reads the YAML, installs anything missing from PSGallery, and imports everything. Modules marked `required: false` fail silently — no ugly red errors when you're on a machine that doesn't have that one niche module you only use on your dev box.

### Path-Based Modules

Notice that `MsixTools` entry? It has a `source` pointing to a `.psd1` file on disk. This is for modules you're actively developing or that aren't published to PSGallery. Snipps imports them directly from the path. No need to mess with `$env:PSModulePath`.

### Graceful Degradation

The whole thing depends on `powershell-yaml` for YAML parsing. What happens if you're on a fresh machine with no internet? The loader catches the failure and skips module loading entirely instead of blowing up your profile. You get a warning, not a wall of red.

### Before and After

**Before** (in `$PROFILE`):

```powershell
Import-Module WingetTools
Import-Module HackF5.ProfileAlias
Import-Module FWH.Prompts
# Wait, do I still use FWH.Prompts? Who knows.
```

**After** (in `$PROFILE`):

```powershell
$env:SnippetsModulesYaml = "$env:USERPROFILE\modules.yml"
```

All the module logic lives in a YAML file you can version control, copy between machines, or diff when something breaks. Your `$PROFILE` stays clean.

---

## PSGallery as a First-Class Repo

Remember how `repos` lets you search every package manager at once? There was always one glaring omission: PowerShell's own module gallery. Not anymore.

Meet `psg`:

```
psg search posh-git

Repo      Command
----      -------
PSGallery Install-Module posh-git -MinimumVersion 1.1.0 -Scope CurrentUser
```

It works exactly like every other snipps repo alias. Search, install, uninstall, list, show — the full set of commands, same consistent interface.

```powershell
psg search Terminal-Icons    # Find modules
psg install posh-git         # Install to CurrentUser
psg list                     # What's installed?
psg show posh-git            # Module details
psg uninstall posh-git       # Clean removal
```

Under the hood, `psg` automatically detects whether your system has the modern `PSResourceGet` module (PowerShell 7.4+) or the legacy `PowerShellGet` and uses the right cmdlets. You don't need to think about it.

And yes, `psg` participates in `repos` searches:

```
repos oh-my-posh

Repo       Command
----       -------
PSGallery  Install-Module oh-my-posh -Scope CurrentUser
scoop      install oh-my-posh@24.8.0
sudo choco install oh-my-posh --version 24.8.0 -y
winget     install XP8K0HKJFRXGCK -s msstore # oh-my-posh
```

Now you can finally answer "which repo has this?" for PowerShell modules too.

---

## Module Reload Alias

Here's a small one that saves me a surprising amount of time. When you're developing a PowerShell module, the edit-import-test cycle looks like this:

```powershell
Remove-Module MyModule -Force
Import-Module MyModule -Force
# test...
# edit...
Remove-Module MyModule -Force
Import-Module MyModule -Force
# repeat forever
```

Now it's just:

```powershell
modrl MyModule
```

Or reload *everything* from your YAML:

```powershell
modrl
```

That's it. `modrl` (module reload) removes the module and re-imports it with `-Force`. When called without arguments, it re-reads your `modules.yml` and reloads every module — including path-based ones, which get resolved back to their file paths from the YAML config.

---

## A Bunch of Fixes Too

While I was in there, I fixed a bunch of things that had been bugging me:

- **`github.ps1` no longer scans your entire C: drive.** It used to call `Get-ChildItem -Recurse` from `C:\` looking for a folder named `github`. On a machine with a large SSD, that's a great way to add 30 seconds to your profile load. Now it searches `$env:USERPROFILE` and `$env:OneDrive` with a depth limit of 1.

- **GitHub Actions workflows are no longer broken.** The CI was using `::set-output` (deprecated in 2022), `actions/checkout@v1`, and a push URL pointing to the wrong org. All fixed.

- **The Oh-My-Posh Windows script now correctly detects Desktop vs Core.** Both branches of the `if/else` were setting `$powershell = 'pwsh'`. Desktop PowerShell gets `'powershell'` now, as it should.

- **`bing.ps1` no longer has a hardcoded API key.** It reads from `$env:BingApiKey` or tells you to set it.

---

## Getting Started

If you're already using snipps, just `snipup` to pull the latest. The module auto-loader activates automatically when a `modules.yml` file is found.

If you're new:

```powershell
# Windows
git clone https://github.com/PS-Services/Snippets.git "$env:OneDrive\Documents\PowerShell\Snippets"

# Linux / macOS
git clone https://github.com/PS-Services/Snippets.git ~/.config/powershell/Snippets
```

Set `$env:Snippets` in `$PROFILE.AllUsersAllHosts`, create a `modules.yml` in your home folder, and you're off. Full setup instructions are in the [README](https://github.com/PS-Services/Snippets) and the [docs site](https://ps-services.github.io/Snippets/).

---

## What's Next

I've been thinking about adding support for module *groups* in the YAML — named sets of modules you can enable or disable depending on context (e.g., `dev`, `ops`, `minimal`). Also considering a `snipps doctor` command that validates your configuration and reports issues.

But for now, I'm pretty happy with where things are. The YAML loader alone has cleaned up my `$PROFILE` across four machines, and `psg` fills a gap I should have filled two years ago.

As always, PRs welcome: [github.com/ps-services/snippets](https://github.com/PS-Services/Snippets)

---

*Tags: PowerShell, Shell, Package Management, Developer Tools, Automation*
