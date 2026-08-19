# Local Store Management System

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**. L'applicazione gestisce catalogo, varianti, barcode, magazzino, cassa, etichette, anagrafiche, export e impostazioni senza richiedere un server o una connessione Internet per il normale utilizzo.

La precedente applicazione C#/Avalonia è stata sostituita dalla versione Flutter, ora presente anche su `main`.

## Download

Le build pubblicate sono disponibili nella sezione **Releases** del repository come file scaricabili direttamente, senza dover estrarre gli artifact di GitHub Actions.

| Sistema | Architettura | Formati |
| --- | --- | --- |
| Windows | x86_64 | `.exe` installer |
| Windows | ARM64 | `.exe` installer |
| Linux | x86_64 | `.AppImage`, `.deb` |
| Linux | ARM64 | `.AppImage`, `.deb` |

Gli artifact mostrati nella pagina **Actions** vengono usati internamente dalla pipeline e GitHub li distribuisce in formato ZIP. Per l'installazione è consigliato usare sempre gli asset della relativa **Release**.

### Linux AppImage

Dopo il download, se necessario:

```bash
chmod +x LocalStoreManagement-linux-x64.AppImage
./LocalStoreManagement-linux-x64.AppImage
```

Per ARM64 usare il file `LocalStoreManagement-linux-arm64.AppImage`.

### Linux DEB

```bash
sudo apt install ./LocalStoreManagement-linux-x64.deb
```

Per ARM64 usare il pacchetto `LocalStoreManagement-linux-arm64.deb`.

## Piattaforme

Attualmente la pipeline produce e verifica pacchetti per:

- Windows x86_64
- Windows ARM64
- Linux x86_64
- Linux ARM64

Il progetto è basato su Flutter desktop. **macOS non è ancora distribuito dalla pipeline corrente**: build, firma e notarizzazione verranno aggiunte separatamente prima di considerarlo una piattaforma ufficialmente supportata dal progetto.

## Interfaccia

L'interfaccia usa Material 3 con uno stile **glassmorphism** applicato all'intera applicazione, in tema chiaro e scuro.

La barra titolo è personalizzata e segue il tema dell'applicazione; mostra il titolo fisso `Local Store Management System` insieme ai controlli nativi di minimizzazione, massimizzazione e chiusura.

Il menu laterale è organizzato in questo ordine:

1. Dashboard
2. Cassa
3. Etichette
4. Prodotti
5. Magazzino
6. Anagrafiche
7. Export
8. Impostazioni

## Funzioni principali

### Catalogo prodotti

Il catalogo è organizzato in **prodotti** e **varianti**.

Ogni prodotto può contenere:

- nome
- marca
- categoria
- prezzo di acquisto
- prezzo di vendita
- note
- stato attivo/disattivato
- una o più varianti

Ogni variante può contenere:

- SKU univoco
- descrizione variante
- taglia
- uno o più barcode
- stato attivo/disattivato
- eventuale override del prezzo di acquisto
- eventuale override del prezzo di vendita

I prezzi appartengono quindi normalmente al prodotto. Una variante usa il prezzo del prodotto salvo quando possiede un override specifico.

La ricerca supporta nome, SKU, barcode, marca, categoria, variante e taglia.

### Dashboard e scanner barcode

Gli scanner USB HID che si comportano come una tastiera funzionano senza driver dedicati e **non richiedono di cliccare prima nel campo di ricerca**.

La Dashboard supporta:

- ricerca rapida tramite barcode/SKU
- visualizzazione immediata dell'articolo trovato
- carico rapido `+1`
- scarico rapido `-1`
- gestione dei barcode sconosciuti

Quando viene scansionato un barcode non presente nel database compare la voce **Aggiungi articolo**. Da lì è possibile:

- creare un nuovo prodotto usando il barcode appena letto
- aggiungere il barcode come nuova variante di un prodotto esistente

Il percorso scanner → ricerca SQLite → aggiornamento UI è ottimizzato per evitare scansioni complete del catalogo durante l'uso della cassa.

### Cassa

La pagina Cassa include:

- scansione barcode/SKU senza focus obbligatorio
- ricerca manuale
- aggiunta rapida al carrello
- incremento automatico della quantità quando lo stesso articolo viene scansionato più volte
- controllo della giacenza disponibile
- sconto percentuale per singola riga
- sconto percentuale sul totale
- più sconti fissi in euro come righe negative rimovibili
- ricalcolo automatico del totale

La giacenza non viene modificata finché non viene completato il flusso di vendita fiscale.

L'integrazione con il registratore telematico è ancora separata dal normale carrello; il pulsante di emissione del documento commerciale rimane disabilitato finché non viene implementato il backend RT.

### Magazzino

Sono disponibili:

- carico
- scarico con controllo disponibilità
- rettifica a giacenza assoluta
- ricerca tramite barcode/SKU
- storico movimenti

La giacenza viene calcolata dalla somma dei movimenti registrati in `stock_movements`.

### Etichette

La sezione Etichette supporta:

- ricerca e scansione barcode/SKU senza focus obbligatorio
- selezione della stampante installata
- memorizzazione persistente dell'ultima stampante usata
- numero copie
- larghezza e altezza fisica in millimetri
- anteprima dell'etichetta
- stampa diretta sulla stampante selezionata
- EAN-13 per codici EAN-13 validi
- Code 128 B per gli altri codici

Il layout è stato riallineato a quello usato dalla precedente versione dell'app: nome e dettagli nella parte superiore, barcode centrale, SKU in basso a sinistra e prezzo in basso a destra.

Su Windows la versione Flutter usa attualmente il percorso di stampa fornito dal pacchetto `printing` e dal driver installato. Non utilizza ancora lo stesso backend GDI nativo della precedente implementazione C#.

### Anagrafiche

Marche e categorie sono gestite separatamente dal catalogo e possono essere create, rinominate, eliminate e riassegnate ai prodotti.

### Export

Sono disponibili export inventario in:

- Excel `.xlsx`
- PDF

Gli export supportano filtri per marca e categoria, raggruppamento per marca e dati del negozio. Il PDF usa font Unicode di sistema per visualizzare correttamente anche il simbolo `€`.

### Impostazioni

È possibile configurare:

- nome negozio
- logo negozio
- icona applicazione personalizzata
- visibilità delle informazioni del negozio nel menu
- tema dell'applicazione

Logo e icone salvati vengono copiati nell'area dati dell'applicazione in modo da rimanere disponibili anche dopo la chiusura del programma.

## Database e compatibilità dati

I dati restano locali sul computer.

Percorso principale:

```text
Documenti/Local Store Management System/
```

Contenuto tipico:

```text
store.db
settings.json
assets/
Backups/
Logs/
```

Lo schema SQLite corrente usa **`PRAGMA user_version = 3`** e comprende principalmente:

- `products`
- `product_variants`
- `product_barcodes`
- `stock_movements`
- `brands`
- `categories`

La versione 3 introduce i prezzi direttamente sul prodotto mantenendo gli eventuali prezzi di variante come override.

Le migrazioni dai precedenti schemi vengono eseguite automaticamente. Prima delle migrazioni strutturali viene creata una copia di sicurezza del database.

Gli indici SQLite includono SKU, barcode, relazioni prodotto/variante e movimenti di magazzino per mantenere rapide le ricerche operative.

## Backup e diagnostica

L'applicazione supporta backup del database e mantiene log diagnostici in:

```text
Documenti/Local Store Management System/Logs/
```

Gli errori Flutter non gestiti e gli errori di inizializzazione vengono registrati. Se il database non può essere aperto o inizializzato, viene mostrata una schermata di errore invece di chiudere l'app senza spiegazioni.

## Sviluppo

È richiesto Flutter stable con il supporto desktop della piattaforma interessata.

### Windows

```powershell
./tool/bootstrap_desktop.ps1
flutter run -d windows
```

Build release:

```powershell
flutter build windows --release
```

### Linux

```bash
./tool/bootstrap_desktop.sh
flutter run -d linux
```

Build release:

```bash
flutter build linux --release
```

## Test

```bash
flutter pub get
flutter analyze --no-fatal-infos
flutter test
```

I test includono anche controlli sullo schema SQLite e sul percorso rapido di ricerca barcode.

## CI, architetture e release

GitHub Actions esegue analisi, test e packaging desktop.

Output previsti:

```text
LocalStoreManagement-Setup-win-x64.exe
LocalStoreManagement-Setup-win-arm64.exe
LocalStoreManagement-linux-x64.AppImage
LocalStoreManagement-linux-x64.deb
LocalStoreManagement-linux-arm64.AppImage
LocalStoreManagement-linux-arm64.deb
```

Strategia branch/release:

- `Flutter` → build di sviluppo pubblicata come prerelease `flutter-latest`
- `test` → prerelease/beta `test-latest`
- `main` → release stabile con tag `v<versione>`

La pipeline usa runner Linux ARM64 nativi per produrre i pacchetti Linux ARM64 e genera installer distinti per le due architetture Windows.

## Dipendenze principali

Tra i pacchetti principali usati dall'applicazione:

- `sqlite3`
- `barcode` / `barcode_widget`
- `pdf`
- `printing`
- `excel`
- `file_selector`
- `window_manager`

Per le versioni esatte fare riferimento a `pubspec.yaml`.

## Versione

La versione dichiarata attualmente in `pubspec.yaml` è:

```text
0.1.3+10
```
