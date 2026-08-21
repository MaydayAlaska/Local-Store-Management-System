# Local Store Management System — Flutter BETA

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `Flutter` è il canale **BETA/TEST** del progetto. La versione BETA corrente è **0.1.8-b1** e viene pubblicata come prerelease `beta-latest`.

La versione stabile corrente su `main` è **0.1.7**. I canali OTA STABLE e BETA sono separati: una build stabile riceve solo release stabili e una build Beta riceve solo prerelease Beta.

## Download BETA

Le build BETA vengono pubblicate per:

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| macOS | Intel x86_64 | `.dmg` con `.app` |
| macOS | Apple Silicon ARM64 | `.dmg` con `.app` |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

## Novità 0.1.8-b1

### Identità e icone Linux

La distribuzione Linux usa ora in modo coerente l'application ID **`com.maydayalaska.local_store_management`**.

- il file desktop installato è `com.maydayalaska.local_store_management.desktop`;
- `Name` resta **Local Store Management System**;
- il runner Flutter Linux viene verificato e configurato con lo stesso `APPLICATION_ID`;
- il riferimento AppStream `launchable` punta allo stesso desktop ID;
- GNOME/Wayland può quindi associare correttamente la finestra alla voce applicazione invece di mostrare il nome tecnico con un'icona generica;
- `StartupWMClass=local_store_management` resta disponibile come associazione per X11.

Le icone Linux vengono generate dalla sorgente ufficiale dell'app nelle dimensioni **16, 32, 48, 64, 128 e 256 px** e installate nella gerarchia `hicolor` con il nome dell'application ID.

L'**AppImage** contiene inoltre il desktop file e l'icona alla radice dell'AppDir, con `.DirIcon` collegato all'icona da 256 px. Il pacchetto **DEB** installa desktop file, icone multi-risoluzione e metadati AppStream e aggiorna, quando disponibili, le cache desktop e icone dopo installazione o rimozione.

L'icona mostrata direttamente sul file `.deb` o `.AppImage` nel file manager dipende comunque dal desktop environment e dal supporto del file manager ai metadati del formato; il pacchetto contiene ora tutte le risorse corrette per l'integrazione dell'applicazione una volta installata o integrata.

La CI controlla esplicitamente che desktop ID, AppStream e application ID del runner restino allineati.

## Funzioni principali

- catalogo prodotti e varianti con SKU, barcode multipli, prezzi e giacenze;
- magazzino con movimenti di carico/scarico;
- cassa con scanner HID, ricerca prodotti, tastierino numerico, sconti, articoli generici e cliente associato;
- clienti con codice identificativo interno, codice fiscale facoltativo e storico acquisti;
- gestione ordini e vendite, annullamento con ripristino della merce ed eliminazione dello storico;
- buoni regalo associati ai clienti, con utilizzo parziale o totale, valore residuo e scadenza facoltativa;
- etichette con anteprima, EAN-13, Code 128 B e stampa diretta TCP/BPL-Z;
- export inventario Excel/PDF, backup e scelta della posizione del database;
- interfaccia in Italiano e English, tema chiaro/scuro/sistema e valuta configurabile;
- traduzioni separate dal codice dell'applicazione tramite file di traduzione esterni;
- aggiornamenti OTA separati tra canale STABLE e canale BETA;
- una sola istanza operativa dell'applicazione alla volta.

## Base stabile 0.1.7

La **0.1.7** ha promosso in stabile il ciclo di sviluppo `0.1.7-b1` → `0.1.7-b6`.

### Buoni regalo

I buoni regalo possono avere una **data di scadenza facoltativa**, impostabile durante l'acquisto e successivamente modificabile o rimovibile dalla scheda cliente.

I nuovi buoni ricevono un codice univoco basato sul timestamp dell'acquisto, nel formato `GIFT-YYYYMMDD-HHMMSS-######`. I codici dei buoni già esistenti non vengono modificati.

Il valore dei buoni usa la valuta configurata nell'applicazione. Il calcolo IVA/VAT della Cassa include anche i buoni regalo in acquisto.

### IVA / VAT in Cassa

L'IVA viene scorporata dal totale già comprensivo di imposta con la formula:

```text
IVA = totale × aliquota / (100 + aliquota)
```

Per esempio, con aliquota 22% e totale 100,00, l'IVA inclusa è 18,03.

### Istanza singola

L'applicazione consente una sola istanza operativa alla volta. La prima istanza riserva un canale IPC locale esclusivo; un secondo avvio richiama la finestra già esistente, la ripristina se minimizzata, la porta in primo piano e termina subito.

La protezione è coperta da un test automatico che verifica anche la possibilità di riaprire normalmente l'applicazione dopo la chiusura della prima istanza.

### Icona applicazione

L'icona predefinita è condivisa dalla distribuzione desktop. Su Windows viene generato un **ICO multi-risoluzione** per applicazione, collegamenti e installer; macOS e Linux usano la stessa sorgente grafica.

### Traduzioni

Le traduzioni sono separate dal codice dell'applicazione e vengono caricate da file dedicati. I nomi delle lingue vengono sempre mostrati nella loro forma nativa, per esempio **Italiano** e **English**.

## Aggiornamenti OTA

Sono presenti due canali indipendenti:

- `main` → **STABLE**, versioni `X.Y.Z`;
- `Flutter` → **BETA**, versioni `X.Y.Z-bN` e prerelease `beta-latest`.

All'avvio l'app controlla gli aggiornamenti. Un aggiornamento viene proposto solo quando la versione online è realmente superiore a quella installata; un commit differente da solo non è sufficiente.

L'updater seleziona automaticamente sistema operativo e architettura senza incrociare x64 e ARM64. Su Windows avvia il nuovo installer, su macOS scarica e apre il DMG, mentre su Linux l'aggiornamento automatico è disponibile quando l'applicazione è stata avviata da AppImage. I pacchetti `.deb` vengono pubblicati per l'installazione manuale.

## Etichette e stampanti

La sezione Etichette supporta profili stampante persistenti, dimensioni fisiche, anteprima, EAN-13 e Code 128 B.

Per le stampanti compatibili è disponibile la stampa diretta:

```text
Flutter → TCP socket → stampante:9100 → BPL-Z/ZPL
```

Le dimensioni configurate nell'app vengono utilizzate anche nella stampa diretta, senza dipendere dal driver di stampa di sistema.

## Esportazione inventario

È possibile scegliere i campi da esportare, tra cui prodotto, variante, SKU, barcode, categoria, giacenza, prezzo di acquisto, prezzo di vendita e stato. La selezione viene rispettata sia nell'export Excel sia nel PDF.

I prezzi esportati e visualizzati usano la valuta configurata nelle Impostazioni.

## Impostazioni

Le preferenze di negozio, tema, lingua, valuta, logo, icona e stampante etichette vengono salvate localmente. I file di impostazioni delle versioni precedenti restano compatibili e i nuovi campi mancanti ricevono valori predefiniti sicuri.

## Database

I dati restano localmente in:

```text
Documenti/Local Store Management System/
```

Lo schema SQLite corrente usa `PRAGMA user_version = 3`. Le migrazioni vengono applicate automaticamente per mantenere compatibili anche i database creati dalle versioni precedenti.

Il dataset dei codici luogo utilizzato per il codice fiscale viene verificato dalla CI rispetto alla fonte aggiornata prima della compilazione delle release.

## Sviluppo e test

### Windows

```powershell
./tool/bootstrap_desktop.ps1
flutter run -d windows
```

### macOS

```bash
flutter create --platforms=macos --project-name local_store_management --org com.maydayalaska .
flutter run -d macos
```

### Linux

```bash
./tool/bootstrap_desktop.sh
flutter run -d linux
```

### Test

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

La CI verifica analisi statica, test automatici, coerenza della versione applicativa, dataset dei codici luogo, identità desktop Linux e metadati AppStream prima di compilare i pacchetti.

## CI e release

Strategia branch:

- `main` → STABLE, tag `v<versione>`, OTA stabile;
- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA Beta;
- `avalonia` → implementazione storica/alternativa.

Per le regole complete vedere `VERSIONING.md`.
