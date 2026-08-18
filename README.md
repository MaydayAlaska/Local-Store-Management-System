# Local Store Management System — Flutter

Gestionale desktop offline per negozio, ora riscritto in **Flutter/Dart**. Il branch `Flutter` sostituisce l'implementazione C#/Avalonia mantenendo compatibilità con il database SQLite e con il flusso operativo già esistente.

## Piattaforme

- Windows x64
- Linux x64
- applicazione desktop nativa, senza browser o server web
- interfaccia Material 3 con barra titolo personalizzata che segue il tema dell'applicazione

## Funzioni migrate

### Catalogo prodotti

- prodotto con una o più varianti
- SKU univoco e uno o più barcode per variante
- nome, marca, categoria, variante, taglia, prezzi di acquisto/vendita, note e stato attivo
- ricerca per nome, SKU, barcode, marca, categoria, variante e taglia
- gestione separata di marche e categorie con rinomina, eliminazione e riassegnazione

### Magazzino

- carico
- scarico con controllo disponibilità
- rettifica a giacenza assoluta
- storico completo dei movimenti
- giacenza sempre derivata dalla somma di `stock_movements.quantity_delta`

### Scanner HID

Gli scanner USB che operano come tastiera continuano a funzionare senza driver dedicati. Dalla Dashboard sono disponibili ricerca/apertura prodotto, carico rapido `+1` e scarico rapido `-1`. Un codice sconosciuto in modalità ricerca apre la creazione prodotto con il barcode precompilato.

### Cassa

- scansione barcode/SKU e ricerca manuale
- carrello temporaneo
- quantità limitata alla giacenza disponibile
- sconto percentuale per singola riga
- sconto percentuale sul totale
- più sconti fissi in euro, mostrati come righe negative rimovibili
- calcolo totale senza modificare il magazzino

L'emissione del documento commerciale resta volutamente disabilitata finché non viene collegato un registratore telematico supportato.

### Etichette

- selezione variante
- anteprima barcode
- EAN-13 quando il codice è valido, Code 128 negli altri casi
- numero copie e dimensioni in millimetri
- generazione PDF e stampa tramite dialogo di sistema Windows/Linux

### Backup ed export

- backup locale del database
- salvataggio backup in un percorso scelto dall'utente
- export inventario Excel e PDF
- filtri per marche/categorie
- raggruppamento alfabetico per marca
- nome negozio negli export e logo nel PDF

### Impostazioni e aggiornamenti

- nome negozio
- icona applicazione personalizzata
- logo negozio
- visibilità nome/logo nel menu
- controllo aggiornamenti su GitHub
- installazione OTA delle release Windows e delle AppImage Linux quando l'app è eseguita da un pacchetto pubblicato

## Compatibilità dati

La posizione resta la stessa dell'app precedente:

`Documenti/Local Store Management System/`

Contenuto principale:

- `store.db`
- `settings.json`
- `assets/`
- `Backups/`

Lo schema SQLite resta alla versione `2` con le tabelle:

- `products`
- `product_variants`
- `product_barcodes`
- `stock_movements`
- `brands`
- `categories`

La migrazione automatica del vecchio schema pre-varianti viene mantenuta e crea una copia di sicurezza prima della conversione.

## Avvio in sviluppo

È richiesto Flutter stable con supporto desktop. I runner nativi sono boilerplate generato da Flutter e vengono creati al primo checkout:

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

Per una build release:

```bash
flutter build linux --release
```

oppure su Windows:

```powershell
flutter build windows --release
```

## CI e pacchetti

GitHub Actions esegue `flutter analyze`, compila Windows e Linux e produce:

- `LocalStoreManagement-Setup-win-x64.exe`
- `LocalStoreManagement-linux-x64.AppImage`

I push sul branch `Flutter` producono artefatti di CI senza pubblicare una release. Il branch `test` continua a pubblicare la prerelease `test-latest`; `main` pubblica release stabili con tag leggibile `v<versione>` e un bridge `ota-<commit>` per l'aggiornamento automatico.

## Versione

La versione Flutter corrente è `0.1.3+10`, equivalente alla precedente `0.1.3.10`.
