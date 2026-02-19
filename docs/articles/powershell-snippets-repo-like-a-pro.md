# PowerShell Snippets: Repo Like a Pro

*The Sharp Ninja · 3 min read · Sep 5, 2023*

*Originally published in [The Unpopular Opinions of a Senior Developer](https://medium.com/the-unpopular-opinions-of-a-senior-developer/powershell-snippets-repo-like-a-pro-84eb266f64b8)*

[github.com/ps-services/snippets](https://github.com/PS-Services/Snippets)

---

Previously I had announced a project that I created called PowerShell Snippets (aka snipps). Snipps sets up a folder at `~\Documents\PowerShell\Snippets` on Windows or `~/.config/powershell/Snippets` on Linux/MacOS and any `.ps1` script found will be loaded into your PS session. If the script has the appropriate header it can also register aliases and functions for use at any time. By default the contents of the github repo [ps-services/snippets](https://github.com/PS-Services/Snippets) are cloned into the folder which includes some useful (at least to me) snippets. My favorite snippets are from a generalized repository framework I created that acts as a consistent interface to several repository managers.

## All Platforms

- `np` — NPM
- `ng` — nuget
- `dn` — dotnet nuget
- `dt` — dotnet tool
- `pp` — pip
- `pps` — pip-search

## Windows

- `wg` — winget
- `scp` — scoop
- `ch` — chocolatey

## Linux / Unix

- `ap` — apt
- `zy` — zypper
- `sn` — snapd
- `br` — homebrew

---

Using the short alias `wg` we can query WinGet for a vital tool such as `gsudo`.

```
wg gsudo

Repo   Command
----   -------
winget install gerardog.gsudo --version 2.4.0  # gsudo
```

The return value is a formatted table where each row is a complete command you can copy and paste to install the search results. Some options you can include are:

- `-raw` — Get a collection of objects that can be streamed to another command
- `-exact` — Return only exact matches
- `-install` — Installs the first result automatically (typically combined with `-exact`)
- `-detailed` — Include the full description of the item (must be combined with the `-raw` switch)
- `-interactive` — Adds a parameter for performing an interactive install to the command
- `-store <name>` — Adds a flag indication a specific store or bucket to search in.

## Multi-Repository Search

In addition to being able to query any of these sources individually, the OS-specific package managers can be queried as a group using the `repos` alias.

```
repos gsudo

Repo       Command
----       -------
winget     install gerardog.gsudo --version 2.4.0  # gsudo
scoop      install gsudo@2.4.0
sudo choco install gsudo --version 2.4.0 -y
```

Notice that the command for chocolatey includes a call to gsudo to elevate the installation command. Each package manager adapter intelligently adds `sudo` to the command if it's necessary.

Another feature is that snipps detects what package managers are installed and ignores the ones that aren't installed. Here we can see results under Pengwin Linux in WSL2 where snap is not installed.

```
repos freeciv -exact

Repo     Command
----     -------
sudo apt install freeciv=3.0.6-1
brew     install freeciv
```

## Standard Commands

All of the package managers can optionally participate in any of the built-in commands:

- `search` — Find a package
- `list` — List installed packages
- `info` — Details for a package
- `install` — Install a package
- `uninstall` — Uninstall a package
- `update` — Update packages cache
- `upgrade` — Upgrade a package

By standardizing the commands across package managers it becomes much easier to create generic scripts that don't care what repo contains a package.

## Finding Where You Installed Something

Another cool use: Don't remember which repo you snagged something from?

```
repos list code

Repo      Command
----      -------
sudo snap remove code
```

`[apt] No results.`

Ah! There it is, I got vscode from snapd.

## Scripting the Results

And of course you can script the results.

```powershell
# Ubuntu Linux
repos freeciv -raw | format-table Repo, Id, Version

Repo      ID                    Version
----      --                    -------
sudo apt  freeciv               3.0.8-1
sudo apt  freeciv-client-extras 3.0.8-1
sudo apt  freeciv-client-gtk    3.0.8-1
sudo apt  freeciv-client-gtk3   3.0.8-1
sudo apt  freeciv-client-qt     3.0.8-1
sudo apt  freeciv-client-sdl    3.0.8-1
sudo apt  freeciv-data          3.0.8-1
sudo apt  freeciv-ruleset-tools 3.0.8-1
sudo apt  freeciv-server        3.0.8-1
sudo snap freeciv21             3.0.1
sudo snap freeciv-gtk           3.1
```

```powershell
# Windows
repos freeciv -raw | format-table Repo, Id, Version

Repo       ID              Version
----       --              -------
winget     FreeCiv.FreeCiv 3.0.8
scoop      freeciv         3.0.8
sudo choco freeciv         3.0.8
```

## Conclusion

I'm kinda proud of this one. I cannot function without it. I hope you find it useful as well!

---

*Tags: PowerShell, Shell, Package Management*
