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

A run of `cats` does not read its own `.bat` files from `C:\Admin\Scripts`: `cats.bat` copies the
installation into a folder of its own under `%TEMP%` and hands over to the copy. `cmd.exe` keeps a
byte offset into the batch file it is running and reopens it after every command, so a `git pull`
over the files being read makes it carry on in the middle of the new content — half a line as a
command, a block outside the `if` that guards it, the dispatcher a second time. The copy is what
makes `cats update Scripts` safe while a chain is running. `CATS_HOME` is that copy, `CATS_ROOT` is
the installation itself: `git`, the system PATH, the `.ps1` helpers, the configuration files and the
scheduled tasks all point at `CATS_ROOT`. See `cats-shadow.bat`.

The update reaches the run that pulled it only from the **next** command on, which is what a copy in
`%TEMP%` means. And there is one pull that cannot be safe, the one that brings this mechanism to a
machine that does not have it yet: install it with `git -C C:\Admin\Scripts pull` from an elevated
prompt, not with `cats update Scripts`.

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
cats [install|update|prepare|create|deploy|clean|resume] [parameters]
```

Case is irrelevant, and the `Cats.` prefix of a recipe name is optional: `cats update Cats.Scripts`
and `cats update Scripts` are the same command. The verbs `uninstall`, `set` and `backup` are declared
in the dispatcher but are **not implemented**.

| Verb | Does | Examples |
|---|---|---|
| [`install`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-install) | Installs a recipe, a shortcut, or any winget package name | `cats install Cats.Base`, `cats install TeamViewerQS`, `cats install 7zip.7zip` |
| [`update`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-update) | Updates the scripts, Office, winget packages and Windows | `cats update Scripts`, `cats update Windows` |
| [`prepare`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-prepare) | Prepares folders, PATH, utilities, users and the machine name | `cats prepare AdminFolders`, `cats prepare WireGuard users`, `cats prepare Machine` |
| [`create`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-create) | Creates local users and the hardware identifier | `cats create Admin mario`, `cats create Machine` |
| [`deploy`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-deploy) | Registers what has to keep running on the machine, and gets it ready for the tenant it joins | `cats deploy Userlogin`, `cats deploy Tenant365` |
| [`clean`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-clean) | Disk cleanup and volume retrim, logs and temporaries, sfc, DISM, network reset, password reset, software removal | `cats clean disks`, `cats clean tmp`, `cats clean Machine`, `cats clean itadmin`, `cats clean Microsoft.Teams` |
| [`resume`](https://github.com/iride-ch-SA/copycat-scripts/wiki/cats-resume) | Carries a chain of steps across the restarts it needs | `cats resume`, `cats resume status`, `cats resume cancel` |

A step that needs a restart before the next one can run does not restart the machine itself: it says
so, and `cats resume` writes down what is left in `C:\Admin\Others\resume.state`, registers a
scheduled task for the `Administrators` group and restarts. The next administrator to sign in picks
the chain up without typing anything. `cats clean Wildcat` and `cats clean Machine` are built on it,
and so are `cats install Drivers` and `cats update Windows`, which run again after the restart until
they find nothing left to do.

Passwords are never typed on the command line: `cats create`, `cats clean User` and
`cats clean itadmin` ask for them, or generate a random one with the `random` keyword.

### Recipes

`Acronis.Agent`, `Adobe.Acrobat.Reader`, `BgInfo`, `Cats.AdminFolders`, `Cats.Base`, `Cats.Scripts`,
`Cats.Utils`, `Cats.Wildcat`, `Drivers`, `G360.Support`, `Google.GWSMO`, `HPSA9`, `LibreOffice`, `Machine`,
`Microsoft.Office`, `Microsoft.Teams`, `Nvidia`, `TeamViewerQS`, `Tenant365`, `User`, `Userlogin`,
`WireGuard`. One page each in the
[Recipes](https://github.com/iride-ch-SA/copycat-scripts/wiki/Recipes) index.

### Scripts outside cats

`sysprep.bat`, `rm-winget-source.bat`, `set-background.bat`, `set-registry.bat`,
`set-permissions.bat`, `reset-power-settings.bat`, `hasher.bat`,
`do-updates.bat`, `userlogin.bat` and a few more are called directly from
`C:\Admin\Scripts`. `cmda.bat` opens a cmd prompt as Administrator. `cats-shadow.bat` is called by
the entry points only, never by hand.

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
