[Tutorial](https://thesharp.ninja/powershell-snippets-tutorial-de75728ba5b0)

# Powershell Snippets System

## Supported Platforms

### Windows

* Windows PowerShell 4.5
* Powershell Core 6.*, 7.*

#### Repositories

| Alias | Repo | Use `sudo` | Notes |
| :---: | ---- | :--------: | ----- |
| wg | winget | no | Defaults to `winget` store.<br/>Add `-Store` parameter to change. |
| scp | scoop | no | Defaults to `main` bucket.<br/>Add `-Store` parameter to change. |
| ch | choco | yes | Always adds `-y` parameter |

### Linux

* Powershell Core 6.*, 7.*

#### Repositories

| Alias | Repo | Use `sudo` | Notes |
| :---: | ---- | :--------: | ----- |
| ap | apt | yes | Adds `-y` parameter as appropriate. |
| br | brew | no |  |
| sn | snap | yes |  |
