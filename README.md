# Local Store Management System — Flutter BETA

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

Il branch `Flutter` è il canale **BETA/TEST** del progetto. Le build di questo branch vengono pubblicate come prerelease `flutter-latest`, mostrano `BETA` nell'applicazione e non installano automaticamente gli aggiornamenti stabili di `main`.

## Download BETA

Le build BETA sono disponibili nella prerelease `flutter-latest` come file diretti per:

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

L'updater stabile distingue automaticamente sistema operativo e architettura:

- Windows x64
- Windows ARM64
- Linux x64 AppImage
- Linux ARM64 AppImage

Le build del branch `Flutter` sono però considerate **BETA** e non possono installare il canale OTA stabile. Le release stabili vengono pubblicate da `main`.

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

- `Flutter` → BETA/TEST, prerelease `flutter-latest`
- `main` → stabile, tag `v<versione>` e OTA stabile
- `test` → canale BETA legacy compatibile

## Versioning

Le versioni stabili usano il formato `X.Y.Z`. Le Beta usano la forma leggibile `X.Y.Z.bN`; nel `pubspec.yaml` la stessa versione viene codificata in SemVer come `X.Y.Z-bN`.

Versione BETA corrente:

```text
0.1.5.b1
```

Per le regole complete vedere `VERSIONING.md`.
