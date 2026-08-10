# Copy Cat (OS Base Templates for Deployment)
[Official Page](https://www.iride.ch/products/cats)

Copy Cat(s) are carefully prepared and thoroughly documented windows templates for rapid and repeated deployment on a variety of heterogeneous hardware. Bases installs are done on dedicated virtual infrastructures and regularly updated and refreshed to grant consistent and reliable deploys.
They are regularly used for distribution of Windows images on hardware supplied to our customers and extensively tested in real use conditions.

## About Copy Cat Scripts
Scripts are a set of tools used and maintained to manage and deploy the Copy Cat(s) templates to Wild Cat(s) hardwares.
Git is used to have a fancy update system and maintain the scripts set into multiples VM and deployed hardwares (Wild Cats) for testing and production use.

## How to use
Run on an administrative cmd terminal:
```bash
winget install --id Git.Git -e --source winget
```
Close cmd, open it again (git should be added in path).

```bash
git clone https://github.com/iride-ch-SA/copycat-scripts.git C:\Admin\Scripts
```
```bash
C:\Admin\Scripts\cats prepare Cats.Scripts
```
Close cmd again, now Cats is added to the path

## Cats Utils
- cmda : Run cmd as Administrator

## Cats Command
### Use Cats to run Copy Cat tools
```bash
  cats [install|uninstall|update|prepare|clean|set|create] [options]
```
### Shortening 
Cats commands are all about shortening (operations, time, command, ...), they are continuosly developed to be as easy and efficient as possible.
#### Uppercase and lowercase
Casing in cats command is completely irrelevant, for reading purposes in guides we use Upper- and lower-case in cats-commands.
#### Cats. Recipes
Every Cats.Recipe is shortable in commands:
***cats update Cats.Scripts*** is fully equivalent to ***cats update Scripts***

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
#### Shortcuts
- Chrome
- Firefox
- VLC
- intelDASA
- gDrive
- qGIS
- WireGuard
- WindowsApp
- GWSMO
- Acrobat
#### Usage
- **cats install BgInfo** : Install BgInfo in C:\Admin\Apps

### cats prepare [recipe|shortcut]
#### Recipes
- Cats.AdminFolders
- Cats.Scripts
- Cats.Utils
- User
#### Shortcuts
- win-updates : prepares Windows for use the **cats update windows** command
- deploy-azure
#### Usage
- **cats prepare AdminFolders** : Create Admin folder structure
- **cats prepare Utils** : Set cleanmgr sageset:1, Disable widget menu bar, Reset Power Settings
- **cats prepare win-updates** : Prepare PSModule e Nuget to permit updates with cats commmands
- **cats prepare deploy-azure** : Prepare login screen for Azure / 365 users

### cats update [recipe]
#### Recipes
- Cats.Scripts
#### Shortcuts
- Windows
#### Usage
- **cats update Scripts** : Update Cats.Scripts from git source
- **cats update Scripts reset** : Fully reset C:\Admin\Scripts folder by deleting and cloning from git source
- **cats update windows** : Do winget updates and windows update

### cats create [recipe|shortcut]
#### Recipes
- User
#### Shortcuts
- Admin

### cats clean [recipe|shortcut]
#### Recipes
- User
#### Shortcuts
- disks : cleanmgr with sagerun:1
- sfc : sfc /scannow
- dism-online : analyse, clean and restore the component store
- network : release, renew, flush dns and set the profile to Private
- win-updates : stop the update services, empty SoftwareDistribution and reboot
- wildcat-deploy : remove the VM drivers
- itadmin : new random password for the itadmin account
#### Usage
- **cats clean itadmin** : replace the itadmin password with a new random one
- **cats clean User** *username* : the same, for any local user

## Cats Recipes
### User
- cats create User *username* *password*|ask|random [Administrators hide]|[no-rdp]
- cats create Admin *username* *password*|ask|random [hide]
- cats prepare User *username* [show|hide]
- cats clean User *username*

#### Passwords
The password must never be typed on the command line: it becomes an argument of `net.exe`, readable in
the command line column of Task Manager, by `wmic process get commandline` and by any endpoint agent,
and it is written to the Security event log when command line auditing is enabled. Use one of:

- **ask** : the password is typed twice and never shown;
- **random** : a 16 character password is generated with lower case, upper case, digits and special
  characters, shown once and stored nowhere. Copy it into the password manager before pressing Enter,
  the console is cleared afterwards.

Passing the password directly still works for backward compatibility and prints a warning.

**random** refuses to run when PowerShell transcription is enabled by policy, on the machine or on the
user, because everything shown on screen is written to the transcript file. The script reports the
policy key and the transcript folder, and asks to change the password with another tool. `-force` runs
it anyway, when the transcript is acceptable and is handled as a secret. A transcript started by hand
with `Start-Transcript` cannot be detected.

`cats clean User` and `cats clean itadmin` always use **random**, and leave the account enabled and
with no expiration date.
