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

### cats prepare [recipe|shortcut]
#### Recipes
- Cats.AdminFolders
- Cats.Scripts
- Cats.Utils
- User
#### Shortcuts
- win-updates : prepares Windows for use the **cats update windows** command
- deploy-azure

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

## Cats Recipes
### User
- cats create User *username* *password* [Administrators hide]|[no-rdp]
- cats create Admin *username* *password* [hide]
- cats prepare User *username* [show|hide]
