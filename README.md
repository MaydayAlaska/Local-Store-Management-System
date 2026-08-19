# Local Store Management System — Flutter BETA

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `Flutter` è il canale **BETA/TEST** del progetto. La versione BETA corrente è **0.1.6-b2**. Le build di questo branch vengono pubblicate come prerelease `beta-latest`, mostrano `BETA` nell'applicazione e ricevono aggiornamenti esclusivamente dal canale OTA BETA.

La versione stabile corrente su `main` è **0.1.5**.

## Download BETA

Le build BETA sono disponibili nella prerelease `beta-latest` per:

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| macOS | Intel x86_64 | `.dmg` con `.app` |
| macOS | Apple Silicon ARM64 | `.dmg` con `.app` |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

## Aggiornamenti OTA

Sono presenti due canali OTA indipendenti:

- `main` → canale **STABILE**
- `Flutter` → canale **BETA**, pubblicato come `beta-latest`

Una build BETA non installa release stabili e una build stabile non installa Beta.

All'avvio viene eseguito automaticamente un controllo aggiornamenti. Se è disponibile una versione realmente più recente, compare una notifica in basso a destra; cliccandola si apre direttamente **Impostazioni**.

Il confronto OTA è monotono per versione: un aggiornamento viene proposto solo quando `versione_online > versione_installata`. Un commit differente, da solo, non è sufficiente. Per esempio:

- `0.1.6-b2 > 0.1.6-b1`
- `0.1.6-b1 > 0.1.5`
- `0.1.5 > 0.1.5-b99`

Il pulsante **Installa aggiornamento** compare solo quando esiste davvero un aggiornamento e il pacchetto è installabile sulla piattaforma corrente.

L'updater seleziona automaticamente Windows, macOS o Linux e x64/ARM64. Su Linux l'installazione automatica è disponibile quando l'app viene avviata da AppImage; i pacchetti `.deb` vengono pubblicati ma non sostituiti automaticamente. Su macOS l'updater scarica e apre il nuovo `.dmg`, dal quale l'utente può sostituire l'applicazione nella cartella Applicazioni.

## Funzioni principali

L'applicazione gestisce catalogo prodotti e varianti, SKU e barcode multipli, prezzi con override per variante, magazzino, cassa, vendite, clienti, etichette, anagrafiche, export, backup e impostazioni.

Gli scanner USB HID funzionano senza focus obbligatorio. Dashboard, Cassa, Magazzino ed Etichette possono ricevere direttamente i barcode dallo scanner.

La sezione Etichette supporta stampante persistente, dimensioni fisiche, anteprima, EAN-13, Code 128 B e stampa diretta.

## Database

I dati restano in:

```text
Documenti/Local Store Management System/
```

Lo schema SQLite corrente usa `PRAGMA user_version = 3`. Le migrazioni vengono eseguite automaticamente con backup preventivo quando necessario.

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

I test dell'updater coprono selezione dell'asset per sistema/architettura, canale Beta, normalizzazione delle versioni e confronto monotono fra Beta e release stabili.

## CI e release

Strategia branch:

- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA BETA
- `main` → STABILE, tag `v<versione>`, OTA stabile
- `avalonia` → implementazione storica/alternativa

Per le regole complete vedere `VERSIONING.md`.
