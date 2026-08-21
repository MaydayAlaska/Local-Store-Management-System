# Local Store Management System

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

La versione stabile corrente è **0.1.7** sul branch `main`.

Il branch `Flutter` resta il canale **BETA/TEST** per lo sviluppo delle versioni successive. I canali OTA STABLE e BETA sono separati: una build stabile riceve solo release stabili e una build Beta riceve solo prerelease Beta.

## Download

Le release stabili vengono pubblicate su GitHub con tag `v<versione>` e includono:

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| macOS | Intel x86_64 | `.dmg` con `.app` |
| macOS | Apple Silicon ARM64 | `.dmg` con `.app` |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

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

## Novità della 0.1.7

La **0.1.7** promuove in stabile il ciclo di sviluppo `0.1.7-b1` → `0.1.7-b6`.

### Buoni regalo

I buoni regalo possono ora avere una **data di scadenza facoltativa**. La scadenza può essere impostata durante l'acquisto e successivamente modificata o rimossa dalla scheda cliente.

I nuovi buoni ricevono un codice univoco basato sul timestamp dell'acquisto, nel formato `GIFT-YYYYMMDD-HHMMSS-######`. I codici dei buoni già esistenti non vengono modificati.

Il valore dei buoni usa la valuta configurata nell'applicazione. Il calcolo IVA/VAT della Cassa include anche i buoni regalo in acquisto.

### IVA / VAT in Cassa

L'IVA viene scorporata correttamente dal totale già comprensivo di imposta con la formula:

```text
IVA = totale × aliquota / (100 + aliquota)
```

Per esempio, con aliquota 22% e totale 100,00, l'IVA inclusa è 18,03.

### Istanza singola

L'applicazione consente una sola istanza operativa alla volta. La prima istanza riserva un canale IPC locale esclusivo; un secondo avvio non apre un nuovo database o una seconda finestra, ma richiama la finestra già esistente, la ripristina se minimizzata, la porta in primo piano e termina subito.

La protezione è coperta da un test automatico che verifica anche la possibilità di riaprire normalmente l'applicazione dopo la chiusura della prima istanza.

### Icona applicazione

L'icona predefinita è condivisa dalla distribuzione desktop. Su Windows viene generato un **ICO multi-risoluzione** per applicazione, collegamenti e installer; macOS e i pacchetti Linux utilizzano la stessa sorgente grafica. AppImage e pacchetti DEB installano l'icona nel formato previsto dal desktop Linux.

### Traduzioni

Le traduzioni sono separate dal codice dell'applicazione e vengono caricate da file dedicati. Questo rende più semplice aggiungere nuove lingue senza inserire direttamente tutte le stringhe nel programma.

I nomi delle lingue vengono sempre mostrati nella loro forma nativa, per esempio **Italiano** e **English**.

## Aggiornamenti OTA

Sono presenti due canali indipendenti:

- `main` → **STABLE**, versioni `X.Y.Z`;
- `Flutter` → **BETA**, versioni `X.Y.Z-bN` e prerelease `beta-latest`.

All'avvio l'app controlla gli aggiornamenti. Un aggiornamento viene proposto solo quando la versione online è realmente superiore a quella installata; un commit differente da solo non è sufficiente.

L'updater seleziona automaticamente sistema operativo e architettura senza incrociare x64 e ARM64. Su Windows avvia il nuovo installer, su macOS scarica e apre il DMG, mentre su Linux l'aggiornamento automatico è disponibile quando l'applicazione è stata avviata da AppImage. I pacchetti `.deb` vengono comunque pubblicati per l'installazione manuale.

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

La CI verifica analisi statica, test automatici, coerenza della versione applicativa, dataset dei codici luogo e metadati Linux prima di compilare i pacchetti desktop.

## CI e release

Strategia branch:

- `main` → STABLE, tag `v<versione>`, OTA stabile;
- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA Beta;
- `avalonia` → implementazione storica/alternativa.

Ogni push su `main` esegue analisi e test, compila i pacchetti desktop e, se tutto termina correttamente, pubblica automaticamente la release stabile.

Per le regole complete vedere `VERSIONING.md`.
