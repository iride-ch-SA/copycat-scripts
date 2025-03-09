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
```

## Cats Command
### Use Cats to run Copy Cat tools
```bash
  cats [install|uninstall|update|prepare|clean|set] [options]
```
#### cats install [recipe|shortcut|winget-name]
##### Recipes
- Acronis.Agent
- Adobe.Acrobat.Reader
- BgInfo
- Cats.Base
- G360.Support
- Google.GWSMO
- Microsoft.Office
##### Shortcuts
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
