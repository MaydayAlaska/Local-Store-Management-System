# Local Store Management System

Gestionale desktop multipiattaforma per negozio, pensato per funzionare **offline** su Windows e Linux.

## Stack

- .NET 10 LTS
- Avalonia UI 12.1.1
- SQLite tramite `Microsoft.Data.Sqlite`
- esportazione Excel tramite `DocumentFormat.OpenXml`
- esportazione PDF tramite PDFsharp + MigraDoc
- Architettura desktop nativa: **nessun browser e nessun server web richiesto**

## Funzioni concordate

1. **Prodotti**: SKU, barcode/EAN, nome, marca, categoria, variante, taglia, prezzo di acquisto, prezzo di vendita, note e stato attivo/disattivato. Variante e taglia sono attributi distinti; non è prevista una scorta minima.
2. **Magazzino**: carico, scarico, rettifica e storico completo dei movimenti. La giacenza è sempre derivata dalla somma dei movimenti e non è modificata direttamente nell'anagrafica prodotto.
3. **Scanner e ricerca Dashboard**: ricerca tramite scanner USB/HID, riconoscimento immediato di SKU/barcode, creazione guidata se il codice non esiste, modalità rapide di carico/scarico da 1 pezzo per scansione e ricerca manuale per nome/SKU/barcode dalla Dashboard.
4. **Etichette**: selezione prodotto, anteprima, EAN-13 quando il codice è valido (Code 128 negli altri casi), numero copie, dimensioni etichetta e stampa tramite le code di sistema Windows/Linux.
5. **Backup ed esportazione**: backup locale del database; esportazione completa dell'inventario in Excel o PDF, raggruppata per marca in ordine alfabetico, oppure esportazione parziale filtrando una o più marche e/o una o più categorie. L'Excel completo usa un unico foglio diviso in sezioni per marca.
6. **Impostazioni**: nome negozio, icona dell'applicazione e logo del negozio da riutilizzare nelle esportazioni Excel/PDF.
7. **Cassa**: pannello di vendita con ricerca/scansione SKU o barcode, carrello temporaneo, quantità e totale. L'emissione del documento commerciale e lo scarico automatico di magazzino restano disattivati finché non viene integrato un registratore telematico supportato.

Non è previsto un modulo separato di inventario fisico/conteggio sessioni.

## Stato attuale sul branch `test`

- anagrafica prodotti: implementata;
- magazzino: carico, scarico, rettifica e storico movimenti implementati;
- scanner: integrazione HID implementata con ricerca/apertura prodotto, creazione da codice sconosciuto, carico rapido +1 e scarico rapido -1;
- Dashboard: ricerca manuale prodotti per nome, SKU e barcode implementata;
- Cassa: pannello base implementato con scanner HID, ricerca prodotti, carrello temporaneo, controllo della disponibilità, modifica quantità e calcolo del totale; pagamento, documento commerciale e scarico magazzino restano volutamente disattivati fino all'integrazione RT;
- etichette: generazione/anteprima e backend di stampa Windows GDI + Linux CUPS implementati; resta da calibrare e verificare fisicamente la ApiX110 con le etichette reali;
- impostazioni: nome negozio, icona programma e logo negozio persistenti implementati;
- backup database: implementato;
- esportazione inventario Excel: implementata con export completo su un unico foglio e filtri parziali per marca/categoria;
- esportazione inventario PDF: implementata con lo stesso raggruppamento e gli stessi filtri dell'Excel.

## Struttura

```text
src/LocalStoreManagement.Desktop/
├── Controls/              # controlli Avalonia personalizzati (anteprima barcode)
├── Data/                  # repository SQLite
├── Infrastructure/        # database, impostazioni, migrazioni e percorsi locali
├── Models/                # modelli applicativi
├── Services/              # barcode, stampa etichette, backup ed esportazioni
├── App.axaml              # bootstrap Avalonia
├── MainWindow.axaml       # shell desktop, Dashboard e navigazione principale
├── CashView.*             # pannello Cassa e carrello di vendita temporaneo
├── LabelsWindow.*         # anteprima e stampa etichette
├── ExportWindow.*         # backup ed esportazioni Excel/PDF
├── SettingsWindow.*       # impostazioni negozio
├── ProductEditorWindow.*  # editor anagrafica prodotto
└── StockMovementWindow.*  # carico/scarico/rettifica
```

## Dati locali

Al primo avvio il programma controlla e, se necessario, crea la cartella **`Documents/Local Store Management System`** dell'utente. Al suo interno vengono salvati:

- `store.db`: database SQLite;
- `settings.json`: impostazioni del negozio;
- `assets/`: icona e logo scelti dall'utente;
- `Backups/`: copie di backup del database create dall'applicazione.

Se esiste un database della precedente versione nella vecchia cartella dati locale e nella nuova cartella non è ancora presente `store.db`, il programma lo copia automaticamente nella nuova posizione.

Il percorso effettivo del database viene mostrato nella Dashboard.

## Avvio in sviluppo

Richiede il .NET 10 SDK.

```bash
dotnet restore src/LocalStoreManagement.Desktop/LocalStoreManagement.Desktop.csproj
dotnet run --project src/LocalStoreManagement.Desktop/LocalStoreManagement.Desktop.csproj
```

Gli stessi sorgenti vengono compilati su Windows e Linux.

## Hardware previsto

Lo scanner di codici a barre viene trattato come dispositivo HID/tastiera: il codice scansionato termina con `Enter` e viene acquisito dal gestionale. Dalla Dashboard si può scegliere tra ricerca/apertura prodotto, carico rapido e scarico rapido. Nel pannello Cassa ogni scansione di una variante vendibile aggiunge un pezzo al carrello, fino alla giacenza disponibile.

Se un codice scansionato non è presente, dalla Dashboard viene aperta la scheda di creazione prodotto con il barcode già compilato; l'utente può completarla oppure annullare. In Cassa il codice sconosciuto viene segnalato senza modificare il carrello.

La stampa delle etichette resta isolata dietro `ILabelPrinter`:

- su **Windows** il gestionale usa GDI e la coda/driver di stampa installata; la misura fisica dell'etichetta va configurata nel driver;
- su **Linux** genera una pagina PDF della misura scelta e la invia tramite `lp` alla coda **CUPS**.

La schermata Etichette rileva le stampanti installate, permette di scegliere il prodotto, il numero di copie e la misura dell'etichetta. La prova fisica con la ApiX110 serve per confermare driver, orientamento, sensore, margini e calibrazione prima di considerare chiusa la parte hardware.

L'integrazione con il registratore telematico è prevista dietro un livello dedicato: finché non sono disponibili protocollo/SDK compatibili, il pulsante di emissione scontrino nel pannello Cassa rimane disabilitato e nessun movimento di magazzino viene generato dal carrello.
