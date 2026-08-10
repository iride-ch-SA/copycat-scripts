# Copy Cat (OS Base Templates for Deployment)
[Pagina ufficiale](https://www.iride.ch/products/cats)

I Copy Cat sono template Windows preparati e documentati per il deploy rapido e ripetuto su hardware
eterogeneo. Le installazioni di base sono realizzate su infrastrutture virtuali dedicate, aggiornate e
rinfrescate periodicamente per garantire deploy coerenti e affidabili. Sono usati per la distribuzione
di immagini Windows sull'hardware fornito alla clientela e provati in condizioni d'uso reali.

Le macchine su cui un Copy Cat viene deployato si chiamano **Wild Cat**.

## Copy Cat Scripts
Copy Cat Scripts è l'insieme di strumenti con cui i template Copy Cat vengono applicati e mantenuti
sulle Wild Cat. Git è il sistema di aggiornamento: gli stessi script vivono su più macchine virtuali e
su tutto l'hardware deployato, in prova e in produzione.

**Ogni commit su `main` è un rilascio.** `cats update Scripts` esegue un `git pull` su
`C:\Admin\Scripts`, quindi qualunque modifica pubblicata raggiunge tutte le Wild Cat al primo
aggiornamento. Non esiste uno stadio intermedio.

Il repository è **pubblico**: non vi si scrive nulla di riservato — credenziali reali, percorsi interni,
indirizzi, chiavi di attivazione, identificativi di tenant. Ciò che viene committato resta nella storia
anche se rimosso in seguito.

## Installazione
Da un terminale cmd **amministrativo**:
```bash
winget install --id Git.Git -e --source winget
```
Chiudere cmd e riaprirlo, così che `git` sia nel path.

```bash
git clone https://github.com/iride-ch-SA/copycat-scripts.git C:\Admin\Scripts
```
```bash
C:\Admin\Scripts\cats prepare Cats.Scripts
```
Chiudere di nuovo cmd: ora `cats` è nel PATH di sistema e si invoca da qualunque cartella.

Quasi tutti i comandi `cats` modificano lo stato della macchina e vanno eseguiti da un prompt elevato.

## Utility
- **cmda** : apre un cmd come Amministratore

## Il comando cats
```bash
  cats [install|update|prepare|clean|create] [parametri]
```
Alla prima esecuzione per ciascun utente, `cats` accetta i contratti delle origini winget: senza,
il primo comando che interroga winget si fermerebbe su una domanda interattiva.

I verbi `uninstall`, `set` e `backup` sono dichiarati nel dispatcher ma **non sono implementati**.

### Abbreviazione
I comandi cats sono pensati per accorciare tutto: operazioni, tempo, digitazione.

#### Maiuscole e minuscole
Sono irrilevanti. Nelle guide si usano maiuscole e minuscole solo per leggibilità.

#### Cats.Recipe
Ogni Cats.Recipe è abbreviabile nei comandi: ***cats update Cats.Scripts*** equivale a
***cats update Scripts***.

---

### cats install [ricetta|shortcut|nome-winget]
#### Ricette
- Acronis.Agent
- Adobe.Acrobat.Reader
- BgInfo
- Cats.Base
- Cats.Utils
- G360.Support
- Google.GWSMO
- Microsoft.Office
#### Shortcut
- Chrome, Firefox, VLC, intelDASA, gDrive, qGIS, WireGuard, WindowsApp
- GWSMO, Acrobat : rimandano alle ricette omonime
#### Uso
- **cats install BgInfo** : installa BgInfo in `C:\Admin\Apps` e ne concede l'esecuzione agli utenti
- **cats install Chrome** : installa il pacchetto winget corrispondente allo shortcut
- **cats install 7zip.7zip** : un nome non riconosciuto come ricetta o shortcut viene passato
  direttamente a winget

Per i pacchetti che arrivano da winget, l'origine viene interrogata prima di procedere: se il pacchetto
risulta già presente viene aggiornato anziché reinstallato, e se il nome corrisponde a più pacchetti
l'operazione si ferma con un errore. Le ricette che scaricano un proprio installatore — Acronis.Agent,
Google.GWSMO, G360.Support — non passano da winget.

### cats update [ricetta|shortcut]
#### Ricette
- Cats.Scripts
- Microsoft.Office
#### Shortcut
- Windows
#### Uso
- **cats update Scripts** : aggiorna Cats.Scripts dal repository git
- **cats update Scripts reset** : ripristina `C:\Admin\Scripts` cancellando la cartella e riclonando
- **cats update Microsoft.Office** : avvia l'aggiornamento della suite Microsoft 365
- **cats update Windows** : aggiornamenti winget e aggiornamenti di Windows

### cats prepare [ricetta|shortcut]
#### Ricette
- Cats.AdminFolders
- Cats.Scripts
- Cats.Utils
- User
#### Shortcut
- win-updates
- deploy-azure
#### Uso
- **cats prepare AdminFolders** : crea la struttura di cartelle `C:\Admin`
- **cats prepare Scripts** : aggiorna gli script e aggiunge `C:\Admin\Scripts` al PATH di sistema
- **cats prepare Utils** : imposta `cleanmgr /sageset:1`, disabilita il menu widget, azzera il
  risparmio energetico
- **cats prepare User** *nomeutente* [show|hide] : mostra o nasconde l'utente nella schermata di accesso
- **cats prepare win-updates** : prepara NuGet e PSWindowsUpdate, necessari a **cats update Windows**
- **cats prepare deploy-azure** : prepara la schermata di accesso per utenti Azure / 365 e nasconde
  `itadmin`

**cats prepare Utils** è interattivo: apre la finestra di Pulizia disco perché l'operatore scelga cosa
includere nel profilo `sageset:1`, e attende un tasto.

### cats create [ricetta|shortcut]
#### Ricette
- User
- HID
#### Shortcut
- Admin
#### Uso
- **cats create User** *nomeutente* : crea l'utente e chiede la password
- **cats create Admin** *nomeutente* : lo stesso, con l'utente in Administrators
- **cats create HID** : calcola l'identificativo hardware della macchina e lo scrive in
  `C:\Admin\Others\HID.txt`

### cats clean [ricetta|shortcut]
#### Ricette
- User
#### Shortcut
- disks : Pulizia disco con il profilo `sagerun:1`
- sfc : `sfc /scannow`
- dism-online : analisi, pulizia e ripristino dell'archivio componenti
- network : rilascio e rinnovo IP, svuotamento cache DNS, profilo di rete su Privata
- win-updates : ferma i servizi di aggiornamento, svuota `SoftwareDistribution` e riavvia
- wildcat-deploy : rimuove i driver della macchina virtuale
- itadmin : nuova password per l'account `itadmin`
#### Uso
- **cats clean itadmin** : sostituisce la password di `itadmin` con una nuova password casuale
- **cats clean itadmin ask** : lo stesso, con la password digitata anziché generata
- **cats clean User** *nomeutente* [ask|random] : lo stesso, per qualunque utente locale

**cats clean win-updates** riavvia la macchina al termine.

---

## Cats Recipes

### User
- cats create User *nomeutente* [*password*|ask|random] [Administrators hide]|[no-rdp]
- cats create Admin *nomeutente* [*password*|ask|random] [hide]
- cats prepare User *nomeutente* [show|hide]
- cats clean User *nomeutente* [ask|random]

Senza opzioni l'utente viene aggiunto al gruppo Utenti desktop remoto. Con `no-rdp` non viene aggiunto
a nessun gruppo, con `Administrators` entra fra gli amministratori, e in quel caso `hide` lo nasconde
anche dalla schermata di accesso.

#### Password
La password non va mai digitata nella riga di comando: diventa un argomento di `net.exe`, leggibile
nella colonna «Riga di comando» di Gestione attività, con `wmic process get commandline` e da qualunque
agente di sicurezza installato, e finisce nel registro Sicurezza (evento 4688) sulle macchine dove è
attivo l'auditing delle righe di comando.

**L'argomento password è facoltativo.** `cats create User mario` equivale a `cats create User mario ask`,
e lo stesso vale quando si indicano solo le opzioni: anche `cats create Admin mario hide` chiede la
password. Le due forme esplicite sono:

- **ask** : la password si digita due volte e non compare mai a schermo;
- **random** : viene generata una password di 16 caratteri con minuscole, maiuscole, cifre e caratteri
  speciali, mostrata una sola volta e non conservata da nessuna parte. Va copiata nel gestore delle
  password prima di premere Invio; subito dopo la console viene pulita.

Passare la password direttamente continua a funzionare per compatibilità e produce un avviso.

**random** si rifiuta di procedere se sulla macchina è attiva la trascrizione di PowerShell, per policy
di macchina o di utente: ogni riga mostrata a schermo finirebbe nel file di trascrizione. Lo script
riporta la chiave di policy e la cartella delle trascrizioni, e invita a cambiare la password con un
altro strumento. Il commutatore `-force` esegue comunque, quando la trascrizione è accettabile e viene
trattata come materiale segreto. Una trascrizione avviata a mano con `Start-Transcript` non è
rilevabile.

`cats clean User` e `cats clean itadmin` accettano le stesse due parole chiave e usano **random** se non
se ne indica nessuna. In entrambi i casi l'account resta attivo e senza data di scadenza.

### Cats.AdminFolders
Crea, se mancanti, `C:\Admin` e le sottocartelle `Apps`, `Drivers`, `Installers`, `Others`.

### Cats.Base
Installa il corredo di base: Chrome, Firefox, VLC, Adobe Acrobat Reader.

### Cats.Utils
- **install** : BgInfo e Acronis Agent
- **prepare** : profilo di Pulizia disco, disattivazione del menu widget, reset del risparmio energetico

### Cats.Scripts
- **prepare** : aggiorna gli script e aggiunge `C:\Admin\Scripts` al PATH **di sistema**, senza toccare
  il PATH dell'utente e senza duplicare la voce se già presente
- **update** : `git pull`; con `reset` cancella la cartella e riclona

### Microsoft.Office
- **install** : installa Microsoft 365 Apps tramite Office Deployment Tool, con la configurazione
  `C:\Admin\Others\office.xml` se presente, altrimenti `C:\Admin\Scripts\config\office.xml`
- **update** : avvia l'aggiornamento della suite già installata

L'installazione è completamente silenziosa: `Display Level="None"` sopprime ogni interfaccia e barra di
avanzamento. Il prompt resta muto per 10–30 minuti mentre l'installazione scarica e procede. Non è un
blocco.

### HID
Calcola un identificativo hardware della macchina come SHA-256 di numero di serie del BIOS, id del
processore, indirizzi MAC delle schede di rete fisiche, seriali dei banchi di memoria e dei dischi.
`cats create HID` lo scrive in `C:\Admin\Others\HID.txt`.

### Acronis.Agent, Google.GWSMO, G360.Support
Scaricano il rispettivo installatore ed eseguono l'installazione. G360.Support crea inoltre il
collegamento «Supporto IT» sul desktop di tutti gli utenti.

---

## Script fuori dal comando cats
Si invocano direttamente da `C:\Admin\Scripts`.

| Script | Funzione |
|---|---|
| `sysprep.bat` | Esegue sysprep in generalize/oobe/shutdown con `config\autounattend.xml` |
| `rm-winget-source.bat` | Rimuove il pacchetto Microsoft.Winget.Source, per utente e da provisioning: **necessario prima di sysprep**, che altrimenti fallisce. Non riavviare fra questo script e sysprep |
| `rename-pc.bat` | Assegna un nome casuale `PC-XXXXXXXXX` e riavvia |
| `set-path.bat` | Aggiunge `C:\Admin\Scripts` al PATH di sistema. Forma storica, sostituita da `cats prepare Scripts` |
| `set-background.bat` | Applica lo sfondo BgInfo. Con `get [nome]` scarica prima l'immagine, con `remove` la elimina |
| `set-registry.bat` | Impostazioni di registro per ambiti: `news-and-interests`, `aad-users`, `local-user`, `wireguard-nonadmin-users` |
| `set-permissions.bat` | Permessi su file installati. Oggi il solo ambito `bginfo` |
| `reset-power-settings.bat` | Disattiva sospensione, ibernazione e spegnimento dello schermo in alimentazione di rete |
| `permit-wireguard-to-user.bat` | Abilita un utente non amministratore all'uso di WireGuard |
| `hasher.bat` | Calcola lo SHA-256 di un file e lo salva in un `.hash` accanto, oppure lo verifica se il `.hash` esiste già |
| `do-acronis-hash.bat` | Applica `hasher.bat` al primo file `.tib` trovato in `A:\` |
| `do-updates.bat` | Aggiornamenti completi: script, winget, Office, Windows. Con `git-only` o `git-reset` si ferma agli script |
| `do-update-gitonly.bat` | Scorciatoia per `do-updates.bat git-only` |
| `userlogin.bat` | Eseguito a ogni accesso: applica lo sfondo e richiama gli script locali eventualmente presenti in `C:\Admin\Others` |
| `deploy-userlogin.bat` | Registra `userlogin.bat` come operazione pianificata all'accesso |

## Contenuto di config
| File | Funzione |
|---|---|
| `autounattend.xml` | Risposte per l'installazione non presidiata e per sysprep |
| `office.xml` | Configurazione dell'Office Deployment Tool: Microsoft 365 Apps, 64 bit, canale Current, lingua italiana |
| `background.bgi`, `solid-color.bgi`, `itadmin.bgi` | Profili BgInfo |
