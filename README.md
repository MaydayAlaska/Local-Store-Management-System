# Local Store Management System

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `main` contiene il canale **STABILE**. La versione stabile corrente è **0.1.5**. Il branch `Flutter` resta il canale **BETA/TEST** per lo sviluppo delle versioni successive.

## Download

Le release stabili vengono pubblicate con tag `vX.Y.Z` e includono:

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

Gli artifact della pagina Actions sono output temporanei della CI; per l'uso normale è preferibile scaricare i file dalla release stabile.

## Funzioni principali

L'applicazione gestisce catalogo prodotti e varianti, SKU e barcode multipli, prezzi a livello prodotto con eventuali override per variante, magazzino, cassa, vendite, clienti, etichette, anagrafiche, export, backup e impostazioni.

Gli scanner USB HID funzionano senza focus obbligatorio. Dashboard, Cassa, Magazzino ed Etichette possono ricevere direttamente i barcode dallo scanner.

La Cassa supporta carrello, quantità, giacenza disponibile, sconti per riga, sconto percentuale totale e sconti fissi in euro. L'emissione del documento commerciale tramite registratore telematico non è ancora integrata.

La sezione Etichette supporta stampante persistente, dimensioni fisiche, anteprima, EAN-13, Code 128 B e stampa diretta.

## Aggiornamenti OTA

Sono presenti due canali OTA indipendenti:

- `main` → canale **STABILE**
- `Flutter` → canale **BETA**, pubblicato come `beta-latest`

Una build stabile non installa Beta e una build Beta non installa release stabili.

All'avvio viene eseguito automaticamente un controllo aggiornamenti. Se è disponibile una versione realmente più recente, compare una notifica discreta in basso a destra; cliccandola si apre direttamente la sezione **Impostazioni**.

Il confronto OTA è basato sulla versione, non sul semplice fatto che il commit online sia diverso. Un aggiornamento viene proposto solo se `versione_online > versione_installata`. Una release con versione uguale o precedente non genera notifiche, anche se il commit è differente.

L'updater seleziona automaticamente il pacchetto corretto per:

- Windows x64
- Windows ARM64
- Linux x64 AppImage
- Linux ARM64 AppImage

Su Linux l'installazione automatica è disponibile quando l'app viene avviata da AppImage. I pacchetti `.deb` vengono pubblicati ma non vengono sostituiti automaticamente dal processo in esecuzione.

## Database

I dati restano in:

```text
Documenti/Local Store Management System/
```

Lo schema SQLite corrente usa `PRAGMA user_version = 3` e comprende prodotti, varianti, barcode, movimenti di magazzino, clienti, vendite e anagrafiche.

Le migrazioni vengono eseguite automaticamente con backup preventivo quando necessario.

## Sviluppo

### Windows

```powershell
./tool/bootstrap_desktop.ps1
flutter run -d windows
```

### Linux

```bash
./tool/bootstrap_desktop.sh
flutter run -d linux
```

## Test

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

I test dell'updater coprono la selezione dell'asset per sistema/architettura, il riconoscimento del canale Beta, la normalizzazione delle versioni e il confronto monotono fra Beta e release stabili.

## CI e release

La pipeline produce:

```text
LocalStoreManagement-Setup-win-x64.exe
LocalStoreManagement-Setup-win-arm64.exe
LocalStoreManagement-linux-x64.AppImage
LocalStoreManagement-linux-x64.deb
LocalStoreManagement-linux-arm64.AppImage
LocalStoreManagement-linux-arm64.deb
```

Strategia branch:

- `main` → STABILE, tag `v<versione>` e OTA stabile
- `Flutter` → BETA/TEST, prerelease `beta-latest` e OTA Beta
- `avalonia` → implementazione storica/alternativa

## Versioning

Le versioni stabili usano il formato `X.Y.Z`. Le Beta usano la forma leggibile `X.Y.Z.bN`; nel `pubspec.yaml` la stessa Beta viene codificata come `X.Y.Z-bN`.

Versione stabile corrente:

```text
0.1.5
```

Il ciclo di sviluppo successivo parte dal branch `Flutter` con `0.1.6.b1`.

Per le regole complete vedere `VERSIONING.md`.
