# Local Store Management System — Flutter BETA

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `Flutter` è il canale **BETA/TEST** del progetto. Le build di questo branch vengono pubblicate come prerelease `beta-latest`, mostrano `BETA` nell'applicazione e ricevono aggiornamenti esclusivamente dal canale OTA BETA. Le release stabili di `main` restano separate.

## Download BETA

Le build BETA sono disponibili nella prerelease `beta-latest` come file diretti per:

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

Gli artifact della pagina Actions sono trasferimenti interni della CI; per provare la Beta è preferibile usare gli asset della prerelease.

## Funzioni principali

La versione Flutter gestisce catalogo prodotti e varianti, SKU e barcode multipli, prezzi a livello prodotto con eventuali override per variante, magazzino, cassa, etichette, anagrafiche, export, backup e impostazioni.

Gli scanner USB HID funzionano senza focus obbligatorio. Dashboard, Cassa, Magazzino ed Etichette possono ricevere direttamente i barcode dallo scanner.

La Cassa supporta carrello, quantità, giacenza disponibile, sconti per riga, sconto percentuale totale e sconti fissi in euro. L'emissione del documento commerciale tramite registratore telematico non è ancora integrata.

La sezione Etichette supporta stampante persistente, dimensioni fisiche, anteprima, EAN-13, Code 128 B e stampa diretta.

## Aggiornamenti OTA

L'updater distingue automaticamente sistema operativo e architettura:

- Windows x64
- Windows ARM64
- Linux x64 AppImage
- Linux ARM64 AppImage

Sono presenti due canali OTA indipendenti:

- `main` → canale **STABILE**
- `Flutter` → canale **BETA**, pubblicato come `beta-latest`

Una build BETA non installa release stabili e una build stabile non installa Beta.

All'avvio dell'app viene eseguito automaticamente un controllo aggiornamenti. Se è disponibile una versione realmente più recente, compare una notifica discreta in basso a destra; cliccandola si apre direttamente la sezione **Impostazioni**, dove è già disponibile il risultato del controllo.

Il confronto OTA è basato sulla versione, non sul semplice fatto che il commit online sia diverso. Un aggiornamento viene proposto solo se `versione_online > versione_installata`. Di conseguenza una release uguale o precedente non genera notifiche, anche se ha un commit differente.

Per le Beta il formato leggibile è `X.Y.Z.bN`: ad esempio `0.1.5.b2` è più recente di `0.1.5.b1`. La release stabile `0.1.5` è considerata successiva a tutte le Beta `0.1.5.bN`.

Su Linux l'installazione automatica è disponibile per AppImage; i pacchetti `.deb` possono essere pubblicati e scaricati ma non vengono sostituiti automaticamente dal processo in esecuzione.

## Database

I dati restano in:

```text
Documenti/Local Store Management System/
```

Lo schema SQLite corrente usa `PRAGMA user_version = 3` e comprende `products`, `product_variants`, `product_barcodes`, `stock_movements`, `brands` e `categories`.

Le migrazioni dai vecchi schemi vengono eseguite automaticamente con backup preventivo quando necessario.

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

I test dell'updater coprono selezione dell'asset per sistema/architettura, riconoscimento del canale Beta, normalizzazione delle versioni e confronto monotono fra Beta e release stabili.

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

Gli asset della prerelease Beta vengono rinominati includendo la versione, per esempio:

```text
LocalStoreManagement-0.1.5.b1-BETA-Setup-win-x64.exe
LocalStoreManagement-0.1.5.b1-BETA-linux-x64.AppImage
```

Strategia branch:

- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA BETA
- `main` → stabile, tag `v<versione>` e OTA stabile
- `avalonia` → implementazione storica/alternativa

## Versioning

Le versioni stabili usano il formato `X.Y.Z`. Le Beta usano la forma leggibile `X.Y.Z.bN`; nel `pubspec.yaml` la stessa versione viene codificata in SemVer come `X.Y.Z-bN`.

Versione BETA corrente:

```text
0.1.5.b1
```

Per le regole complete vedere `VERSIONING.md`.
