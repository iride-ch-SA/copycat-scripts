# Copy Cat (OS Base Templates for Deployment)
[Official page](https://www.iride.ch/products/cats)

Copy Cats are Windows templates prepared and documented for fast, repeatable deployment on
heterogeneous hardware. The base installations are built on dedicated virtual infrastructure, updated
and refreshed periodically to guarantee consistent, reliable deployments. They are used to distribute
Windows images onto the hardware supplied to customers, and are tested under real operating conditions.

The machines a Copy Cat is deployed onto are called **Wild Cats**.

## Copy Cat Scripts
Copy Cat Scripts is the toolset used to apply and maintain Copy Cat templates on Wild Cats. Git is the
update mechanism: the same scripts live on several virtual machines and on all deployed hardware, both
under test and in production.

**Every commit on `main` is a release.** `cats update Scripts` runs a `git pull` on `C:\Admin\Scripts`,
so any published change reaches every Wild Cat at the first update. There is no intermediate stage.

The repository is **public**: nothing confidential goes into it — real credentials, internal paths,
addresses, activation keys, tenant identifiers. Whatever is committed stays in the history even if
removed later.

## Installation
From an **elevated** cmd prompt:
```bash
winget install --id Git.Git -e --source winget
```
Close cmd and reopen it, so that `git` is on the path.

```bash
git clone https://github.com/iride-ch-SA/copycat-scripts.git C:\Admin\Scripts
```
```bash
C:\Admin\Scripts\cats prepare Cats.Scripts
```
Close cmd again: `cats` is now on the system PATH and can be called from any folder.

Almost every `cats` command changes the state of the machine and must be run from an elevated prompt.

## Utilities
- **cmda** : opens a cmd prompt as Administrator

## The cats command
```bash
  cats [install|update|prepare|clean|create] [parameters]
```
On its first run for each user, `cats` accepts the winget source agreements: without them, the first
command that queries winget would stop on an interactive question.

The verbs `uninstall`, `set` and `backup` are declared in the dispatcher but are **not implemented**.

### Shorthand
The cats commands are designed to shorten everything: operations, time, typing.

#### Case
Case is irrelevant. Guides use mixed case for readability only.

#### Cats.Recipe
Every Cats.Recipe can be abbreviated in commands: ***cats update Cats.Scripts*** is equivalent to
***cats update Scripts***.

---

### cats install [recipe|shortcut|winget-name]
#### Recipes
- Acronis.Agent
- Adobe.Acrobat.Reader
- BgInfo
- Cats.Base
- Cats.Utils
- G360.Support
- Google.GWSMO
- Microsoft.Office
- TeamViewerQS
#### Shortcuts
- Chrome, Firefox, VLC, intelDASA, gDrive, qGIS, WireGuard, WindowsApp
- GWSMO, Acrobat : aliases of the recipes of the same name
#### Usage
- **cats install BgInfo** : installs BgInfo into `C:\Admin\Apps` and grants users the right to run it
- **cats install TeamViewerQS** : makes TeamViewer QuickSupport available to every user of the machine
- **cats install Chrome** : installs the winget package matching the shortcut
- **cats install 7zip.7zip** : a name that is neither a recipe nor a shortcut is passed straight to
  winget

For packages coming from winget, the source is queried before proceeding: if the package is already
present it is updated instead of reinstalled, and if the name matches more than one package the
operation stops with an error. The recipes that download their own installer — Acronis.Agent,
Google.GWSMO, G360.Support, TeamViewerQS — do not go through winget, except TeamViewerQS which falls
back to it when the vendor download fails.

### cats update [recipe|shortcut]
#### Recipes
- Cats.Scripts
- Microsoft.Office
#### Shortcuts
- Windows
#### Usage
- **cats update Scripts** : updates Cats.Scripts from the git repository
- **cats update Scripts reset** : restores `C:\Admin\Scripts` by deleting the folder and cloning again
- **cats update Microsoft.Office** : starts the update of the Microsoft 365 suite
- **cats update Windows** : winget updates and Windows updates

### cats prepare [recipe|shortcut]
#### Recipes
- Cats.AdminFolders
- Cats.Scripts
- Cats.Utils
- User
#### Shortcuts
- win-updates
- deploy-azure
#### Usage
- **cats prepare AdminFolders** : creates the `C:\Admin` folder structure
- **cats prepare Scripts** : updates the scripts and adds `C:\Admin\Scripts` to the system PATH
- **cats prepare Utils** : sets up `cleanmgr /sageset:1`, disables the widget menu, resets power saving
- **cats prepare User** *username* [show|hide] : shows or hides the user on the sign-in screen
- **cats prepare win-updates** : prepares NuGet and PSWindowsUpdate, required by **cats update Windows**
- **cats prepare deploy-azure** : prepares the sign-in screen for Azure / 365 users and hides `itadmin`

**cats prepare Utils** is interactive: it opens the Disk Cleanup window so the operator can choose what
to include in the `sageset:1` profile, and waits for a key press.

### cats create [recipe|shortcut]
#### Recipes
- User
- HID
#### Shortcuts
- Admin
#### Usage
- **cats create User** *username* : creates the user and asks for the password
- **cats create Admin** *username* : the same, with the user in Administrators
- **cats create HID** : computes the hardware identifier of the machine and writes it to
  `C:\Admin\Others\HID.txt`

### cats clean [recipe|shortcut]
#### Recipes
- User
#### Shortcuts
- disks : Disk Cleanup with the `sagerun:1` profile
- sfc : `sfc /scannow`
- dism-online : component store scan, cleanup and repair
- network : IP release and renew, DNS cache flush, network profile set to Private
- win-updates : stops the update services, empties `SoftwareDistribution` and reboots
- wildcat-deploy : removes the virtual machine drivers
- itadmin : new password for the `itadmin` account
#### Usage
- **cats clean itadmin** : replaces the `itadmin` password with a new random one
- **cats clean itadmin ask** : the same, with the password typed in instead of generated
- **cats clean User** *username* [ask|random] : the same, for any local user

**cats clean win-updates** reboots the machine when done.

---

## Cats Recipes

### User
- cats create User *username* [*password*|ask|random] [Administrators hide]|[no-rdp]
- cats create Admin *username* [*password*|ask|random] [hide]
- cats prepare User *username* [show|hide]
- cats clean User *username* [ask|random]

With no options the user is added to the Remote Desktop Users group. With `no-rdp` the user is added to
no group at all, with `Administrators` the user joins the administrators, and in that case `hide` also
hides the user from the sign-in screen.

#### Password
The password must never be typed on the command line: it becomes an argument to `net.exe`, readable in
the "Command line" column of Task Manager, through `wmic process get commandline` and by any installed
security agent, and it ends up in the Security log (event 4688) on machines where command line auditing
is enabled.

**The password argument is optional.** `cats create User mario` is equivalent to
`cats create User mario ask`, and the same holds when only options are given:
`cats create Admin mario hide` asks for the password too. The two explicit forms are:

- **ask** : the password is typed twice and never appears on screen;
- **random** : a 16-character password is generated with lowercase, uppercase, digits and special
  characters, shown once and kept nowhere. It must be copied into the password manager before pressing
  Enter; the console is cleared immediately afterwards.

Passing the password directly still works for compatibility and produces a warning.

**random** refuses to proceed if PowerShell transcription is enabled on the machine, by machine or user
policy: every line shown on screen would end up in the transcript file. The script reports the policy
key and the transcript folder, and suggests changing the password with another tool. The `-force`
switch runs anyway, when the transcript is acceptable and is treated as secret material. A transcript
started by hand with `Start-Transcript` cannot be detected.

`cats clean User` and `cats clean itadmin` accept the same two keywords and use **random** if none is
given. In both cases the account stays enabled and with no expiry date.

### Cats.AdminFolders
Creates `C:\Admin` and the `Apps`, `Drivers`, `Installers`, `Others` subfolders if missing.

### Cats.Base
Installs the base set: Chrome, Firefox, VLC, Adobe Acrobat Reader.

### Cats.Utils
- **install** : BgInfo and Acronis Agent
- **prepare** : Disk Cleanup profile, widget menu disabled, power saving reset

### Cats.Scripts
- **prepare** : updates the scripts and adds `C:\Admin\Scripts` to the **system** PATH, without touching
  the user PATH and without duplicating the entry if already present
- **update** : `git pull`; with `reset` it deletes the folder and clones again

### Microsoft.Office
- **install** : installs Microsoft 365 Apps through the Office Deployment Tool, using the configuration
  `C:\Admin\Others\office.xml` if present, otherwise `C:\Admin\Scripts\config\office.xml`
- **update** : starts the update of the already installed suite

The installation is completely silent: `Display Level="None"` suppresses every interface and progress
bar. The prompt stays quiet for 10–30 minutes while the installation downloads and proceeds. This is
not a hang.

### HID
Computes a hardware identifier of the machine as the SHA-256 of the BIOS serial number, the processor
id, the MAC addresses of the physical network adapters and the serial numbers of the memory modules and
disks. `cats create HID` writes it to `C:\Admin\Others\HID.txt`.

### Acronis.Agent, Google.GWSMO, G360.Support
They download their respective installer and run the installation. G360.Support also creates the "IT
Support" shortcut on the desktop of all users.

### TeamViewerQS
- **install** : downloads the current TeamViewer QuickSupport from the vendor to
  `C:\Admin\Apps\TeamViewerQS.exe` — falling back to winget if that download fails —, grants the `Users`
  group the right to run it, and creates the "TeamViewer QuickSupport" shortcut on the desktop of all
  users, `C:\Users\Public\Desktop`

QuickSupport needs no installation and no administrator rights to run: a single executable in a
machine-wide folder, readable and runnable by every user, is what "installed for all users" means here.
The download always comes from `download.teamviewer.com` and not from the CopyCats bucket, because a
QuickSupport module has to match the version of the supporter's TeamViewer: pinning a copy would age.
The fallback installs `TeamViewer.TeamViewer.QuickSupport` with `--location C:\Admin\Apps`: the package
is `portable` and its command alias is `TeamViewerQS`, so winget lands the executable at the very same
path the rest of the recipe expects. It is a fallback and not the primary way because the winget manifest
carries the same vendor URL plus a pinned SHA256, which fails while the manifest lags behind a new
TeamViewer build; its one real gain is following the URL if the vendor ever changes it.
Running the recipe again refreshes both the executable and the shortcut, so it is also the way to update
it. Removal is manual: delete the shortcut and the executable.

---

## Scripts outside the cats command
They are called directly from `C:\Admin\Scripts`.

| Script | Function |
|---|---|
| `sysprep.bat` | Runs sysprep in generalize/oobe/shutdown with `config\autounattend.xml` |
| `rm-winget-source.bat` | Removes the Microsoft.Winget.Source package, per user and from provisioning: **required before sysprep**, which would otherwise fail. Do not reboot between this script and sysprep |
| `rename-pc.bat` | Assigns a random `PC-XXXXXXXXX` name and reboots |
| `set-path.bat` | Adds `C:\Admin\Scripts` to the system PATH. Legacy form, superseded by `cats prepare Scripts` |
| `set-background.bat` | Applies the BgInfo wallpaper. With `get [name]` it downloads the image first, with `remove` it deletes it. When the machine defines no background at all — no `.bgi` profile and no `background.jpg` — it downloads the `Trust` image and applies it; the solid colour stays as the fallback if the download fails |
| `set-registry.bat` | Registry settings by scope: `news-and-interests`, `aad-users`, `local-user`, `wireguard-nonadmin-users` |
| `set-permissions.bat` | Permissions on installed files. Today the `bginfo` and `teamviewerqs` scopes |
| `reset-power-settings.bat` | Disables sleep, hibernation and screen turn-off on AC power |
| `permit-wireguard-to-user.bat` | Allows a non-administrator user to use WireGuard |
| `hasher.bat` | Computes the SHA-256 of a file and saves it to a `.hash` alongside it, or verifies it if the `.hash` already exists |
| `do-acronis-hash.bat` | Applies `hasher.bat` to the first `.tib` file found in `A:\` |
| `do-updates.bat` | Full updates: scripts, winget, Office, Windows. With `git-only` or `git-reset` it stops at the scripts |
| `do-update-gitonly.bat` | Shortcut for `do-updates.bat git-only` |
| `userlogin.bat` | Run at every sign-in: applies the wallpaper and calls the local scripts present in `C:\Admin\Others`, if any |
| `deploy-userlogin.bat` | Registers `userlogin.bat` as a scheduled task at sign-in |

## Contents of config
| File | Function |
|---|---|
| `autounattend.xml` | Answers for the unattended installation and for sysprep |
| `office.xml` | Office Deployment Tool configuration: Microsoft 365 Apps, 64-bit, Current channel, Italian language |
| `background.bgi`, `solid-color.bgi`, `itadmin.bgi` | BgInfo profiles |
