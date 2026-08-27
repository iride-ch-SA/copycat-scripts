# Copy Cat (OS Base Templates for Deployment)

Copy Cats are Windows templates prepared and documented for fast, repeatable deployment on
heterogeneous hardware, built on dedicated virtual infrastructure and refreshed periodically. The
machines a Copy Cat is deployed onto are called **Wild Cats**.

**Copy Cat Scripts** is the toolset that applies and maintains those templates on Wild Cats: user
creation, application install, registry settings, permissions, wallpaper, sysprep, updates.

Git is the update mechanism, so **every commit on `main` is a release**: `cats update Scripts` runs a
`git pull` on `C:\Admin\Scripts` and any published change reaches every Wild Cat at the first update.
The repository is **public** — nothing confidential goes into it, and whatever is committed stays in
the history even if removed later.

## Installation

From an **elevated** cmd prompt:

```bash
winget install --id Git.Git -e --source winget
```

Close cmd and reopen it, so that `git` is on the path.

```bash
git clone https://github.com/iride-ch-SA/copycat-scripts.git C:\Admin\Scripts
C:\Admin\Scripts\cats prepare Cats.Scripts
```

Close cmd again: `cats` is now on the system PATH and can be called from any folder. Almost every
`cats` command changes the state of the machine and must be run from an elevated prompt.

## The cats command

```bash
cats [install|update|prepare|clean|create] [parameters]
```

Case is irrelevant, and the `Cats.` prefix of a recipe name is optional: `cats update Cats.Scripts`
and `cats update Scripts` are the same command. The verbs `uninstall`, `set` and `backup` are declared
in the dispatcher but are **not implemented**.

| Verb | Does | Examples |
|---|---|---|
| [`install`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-install) | Installs a recipe, a shortcut, or any winget package name | `cats install Cats.Base`, `cats install TeamViewerQS`, `cats install 7zip.7zip` |
| [`update`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-update) | Updates the scripts, Office, winget packages and Windows | `cats update Scripts`, `cats update Windows` |
| [`prepare`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-prepare) | Prepares folders, PATH, utilities, users, deployment | `cats prepare AdminFolders`, `cats prepare deploy-azure` |
| [`create`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-create) | Creates local users and the hardware identifier | `cats create Admin mario`, `cats create HID` |
| [`clean`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-clean) | Disk cleanup, sfc, DISM, network reset, password reset | `cats clean disks`, `cats clean itadmin` |

Passwords are never typed on the command line: `cats create`, `cats clean User` and
`cats clean itadmin` ask for them, or generate a random one with the `random` keyword.

### Recipes

`Acronis.Agent`, `Adobe.Acrobat.Reader`, `BgInfo`, `Cats.AdminFolders`, `Cats.Base`, `Cats.Scripts`,
`Cats.Utils`, `G360.Support`, `Google.GWSMO`, `HID`, `HPSA9`, `LibreOffice`, `Microsoft.Office`,
`Nvidia`, `TeamViewerQS`, `User`. One page each in the
[Recipes](https://github.com/iride-ch-SA/copycat-scripts/wiki/Recipes) index.

### Scripts outside cats

`sysprep.bat`, `rm-winget-source.bat`, `rename-pc.bat`, `set-background.bat`, `set-registry.bat`,
`set-permissions.bat`, `reset-power-settings.bat`, `permit-wireguard-to-user.bat`, `hasher.bat`,
`do-updates.bat`, `userlogin.bat`, `deploy-userlogin.bat` and a few more are called directly from
`C:\Admin\Scripts`. `cmda.bat` opens a cmd prompt as Administrator.

## Documentation

Everything is documented in the
[wiki](https://github.com/iride-ch-SA/copycat-scripts/wiki):

- [Getting Started](https://github.com/iride-ch-SA/copycat-scripts/wiki/Getting-Started) — first
  deployment, end to end
- [The cats command](https://github.com/iride-ch-SA/copycat-scripts/wiki/The-cats-command) — syntax,
  shorthand, dispatcher
- [Recipes](https://github.com/iride-ch-SA/copycat-scripts/wiki/Recipes) — one page per recipe
- [Deployment](https://github.com/iride-ch-SA/copycat-scripts/wiki/Scripts-Deployment),
  [Configuration](https://github.com/iride-ch-SA/copycat-scripts/wiki/Scripts-Configuration),
  [Maintenance](https://github.com/iride-ch-SA/copycat-scripts/wiki/Scripts-Maintenance) — the scripts
  outside `cats`
- [PowerShell helpers](https://github.com/iride-ch-SA/copycat-scripts/wiki/PowerShell-Helpers) and
  [configuration files](https://github.com/iride-ch-SA/copycat-scripts/wiki/Configuration-Files)
- [Troubleshooting](https://github.com/iride-ch-SA/copycat-scripts/wiki/Troubleshooting)
- [Writing a recipe](https://github.com/iride-ch-SA/copycat-scripts/wiki/Writing-a-recipe)
