# Local Store Management System — Flutter BETA

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `Flutter` è il canale **BETA/TEST** del progetto. La versione BETA corrente è **0.1.6-b5**. Le build di questo branch vengono pubblicate come prerelease `beta-latest`, mostrano `BETA` nell'applicazione e ricevono aggiornamenti esclusivamente dal canale OTA BETA.

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

La separazione è rigida anche a livello di versione: il canale BETA accetta esclusivamente versioni nel formato `X.Y.Z-bN`, mentre il canale STABILE accetta esclusivamente versioni `X.Y.Z` senza suffisso Beta. Una build BETA non propone né installa release stabili e una build stabile non propone né installa Beta, anche in presenza di tag o metadata GitHub incoerenti.

All'avvio viene eseguito automaticamente un controllo aggiornamenti. Se è disponibile una versione realmente più recente, compare una notifica in basso a destra; cliccandola si apre direttamente **Impostazioni**.

Il confronto OTA è monotono per versione: un aggiornamento viene proposto solo quando `versione_online > versione_installata`. Un commit differente, da solo, non è sufficiente. Per esempio:

- `0.1.6-b5 > 0.1.6-b4`
- `0.1.6-b1 > 0.1.5`
- `0.1.5 > 0.1.5-b99`

Il pulsante **Installa aggiornamento** compare solo quando esiste davvero un aggiornamento e il pacchetto è installabile sulla piattaforma corrente.

L'updater seleziona automaticamente Windows, macOS o Linux e x64/ARM64. Su Linux l'installazione automatica è disponibile quando l'app viene avviata da AppImage; i pacchetti `.deb` vengono pubblicati ma non sostituiti automaticamente. Su macOS l'updater scarica e apre il nuovo `.dmg`, dal quale l'utente può sostituire l'applicazione nella cartella Applicazioni.

## Funzioni principali

L'applicazione gestisce catalogo prodotti e varianti, SKU e barcode multipli, prezzi con override per variante, magazzino, cassa, vendite, clienti, etichette, anagrafiche, export, backup e impostazioni.

Gli scanner USB HID funzionano senza focus obbligatorio. Dashboard, Cassa, Magazzino ed Etichette possono ricevere direttamente i barcode dallo scanner.

La sezione Etichette supporta stampante persistente, dimensioni fisiche, anteprima, EAN-13, Code 128 B e stampa diretta TCP/BPL-Z quando configurata.

### Novità 0.1.6-b5

- scelta persistente della **valuta**: EUR, USD, GBP o CHF;
- scelta del **tema**: sistema, chiaro o scuro;
- interfaccia selezionabile in **Italiano o Inglese**;
- menu laterale verticalmente scorrevole quando l'altezza della finestra non permette di mostrare tutte le voci, senza scrollbar visibile;
- logo del negozio più grande nel menu laterale;
- controlli finestra ridisegnati con icone vettoriali più pulite;
- pulsante **Salva impostazioni** spostato nell'intestazione in alto a destra;
- esportazione inventario con selezione delle colonne da includere;
- nomi export nel formato `Inventario - YYYY-MM-DD_HH-MM-SS`;
- nuovi SKU generati in formato esadecimale, mantenendo validi gli SKU già esistenti;
- la sezione **Aggiornamenti** resta sempre l'ultima nelle Impostazioni;
- separazione rigida tra versioni OTA BETA e STABLE.

## Esportazione inventario

Prima dei filtri per marca e categoria è possibile scegliere quali campi esportare: prodotto, variante, SKU, barcode, categoria, giacenza, prezzo di acquisto, prezzo di vendita e stato. La selezione viene rispettata sia nell'export Excel sia nel PDF.

I prezzi esportati e visualizzati usano la valuta configurata nelle Impostazioni.

## Impostazioni

Le preferenze di negozio, tema, lingua, valuta, logo, icona e ultima stampante etichette vengono salvate localmente. I vecchi file di impostazioni restano compatibili: i nuovi campi mancanti assumono automaticamente i valori predefiniti `EUR`, tema di sistema e Italiano.

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

I test dell'updater coprono selezione dell'asset per sistema/architettura, separazione dei canali Beta/Stable, normalizzazione delle versioni e confronto monotono fra Beta e release stabili.

## CI e release

Strategia branch:

- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA BETA
- `main` → STABILE, tag `v<versione>`, OTA stabile
- `avalonia` → implementazione storica/alternativa

Per le regole complete vedere `VERSIONING.md`.
