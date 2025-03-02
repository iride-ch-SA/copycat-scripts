# Copy Cat (OS Base Templates for Deployment)
[Official Page](https://www.iride.ch/products/cats)

Copy Cat(s) are carefully prepared and thoroughly documented windows templates for rapid and repeated deployment on a variety of heterogeneous hardware. Bases installs are done on dedicated virtual infrastructures and regularly updated and refreshed to grant consistent and reliable deploys.
They are regularly used for distribution of Windows images on hardware supplied to our customers and extensively tested in real use conditions.

## About Scripts
Scripts are a set of tools used and maintained to manage and deploy the Copy Cat(s) templates to Wild Cat(s) hardwares.
Git is used to fancy update and maintain the scripts set into multiples VM for testing and production use.

## Hot to use
Run on an administrative cmd terminal:
```bash
winget install --id Git.Git -e --source winget
git clone https://github.com/iride-ch-SA/copycat-scripts.git C:\Admin\Scripts
C:\Admin\Scripts\cats-prepare.bat
```

Add *template* for a clean run on VM templates to the cats-prepare.bat script

## Scripts
### cats-clean.bat [win-updates|sfc|dism-online|network]
- clean: Do a cleanmgr on sagerun:1
- win-updates: Clean software distribution by stopping wuauserv
- sfc: do an sfc /scannow
- dism-online: Cleanup-Image
- network: reset network and set to private

### install-destination-softwares.bat [template|base|support]
- template: Install Acronis Agent
- base: Install
  - Google Chrome
  - Mozilla Firefox
  - Adobe Acrobat Reader (64bit)
  - VideoLAN VLC
  - Office 365 (it-it, 64bit)
- support: Install Remote Support Tool
- intelnuc:
  - Install Intel Driver and Support Assistant
- windowsapp: Install Windows App for the current user
