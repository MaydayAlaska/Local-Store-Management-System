# Local Store Management System

Gestionale desktop multipiattaforma per negozio, pensato per funzionare **offline** su Windows e Linux.

## Stack

- .NET 10 LTS
- Avalonia UI 12.1.1
- SQLite tramite `Microsoft.Data.Sqlite`
- Architettura desktop nativa: **nessun browser e nessun server web richiesto**

## Funzioni concordate

1. **Prodotti**: SKU, barcode/EAN, nome, marca, categoria, variante, taglia, prezzo di acquisto, prezzo di vendita, note e stato attivo/disattivato. Variante e taglia sono attributi distinti; non è prevista una scorta minima.
2. **Magazzino**: carico, scarico, rettifica e storico completo dei movimenti. La giacenza è sempre derivata dalla somma dei movimenti e non è modificata direttamente nell'anagrafica prodotto.
3. **Scanner**: ricerca tramite scanner USB/HID, riconoscimento immediato di SKU/barcode, creazione guidata se il codice non esiste e modalità rapide di carico/scarico da 1 pezzo per scansione.
4. **Etichette**: generazione barcode, anteprima, numero copie e stampa ApiX110 su Windows/Linux tramite backend di stampa separato.
5. **Backup ed Excel**: backup locale del database; esportazione completa dell'inventario raggruppata per marca in ordine alfabetico oppure esportazione parziale filtrando una o più marche e/o una o più categorie.

Non è previsto un modulo separato di inventario fisico/conteggio sessioni.

## Stato attuale sul branch `test`

- anagrafica prodotti: implementata;
- magazzino: carico, scarico, rettifica e storico movimenti implementati;
- scanner: integrazione HID implementata con ricerca/apertura prodotto, creazione da codice sconosciuto, carico rapido +1 e scarico rapido -1;
- etichette: da implementare;
- backup/esportazione Excel: da implementare.

## Struttura

```text
src/LocalStoreManagement.Desktop/
├── Data/                 # repository SQLite
├── Infrastructure/       # database, migrazioni e percorsi locali
├── Models/               # modelli applicativi
├── Services/             # servizi hardware/applicativi
├── App.axaml             # bootstrap Avalonia
├── MainWindow.axaml      # shell desktop e flusso scanner
├── ProductEditorWindow.* # editor anagrafica prodotto
└── StockMovementWindow.* # carico/scarico/rettifica
```

Il database viene creato al primo avvio nella cartella dati utente del sistema operativo. Il percorso viene mostrato nella schermata principale.

## Avvio in sviluppo

Richiede il .NET 10 SDK.

```bash
dotnet restore src/LocalStoreManagement.Desktop/LocalStoreManagement.Desktop.csproj
dotnet run --project src/LocalStoreManagement.Desktop/LocalStoreManagement.Desktop.csproj
```

Gli stessi sorgenti vengono compilati su Windows e Linux.

## Hardware previsto

Lo scanner di codici a barre viene trattato come dispositivo HID/tastiera: il codice scansionato termina con `Enter` e viene acquisito dal gestionale. Dalla dashboard si può scegliere tra ricerca/apertura prodotto, carico rapido e scarico rapido. Nelle modalità rapide ogni scansione corrisponde a un singolo pezzo.

Se un codice scansionato non è presente, viene aperta la scheda di creazione prodotto con il barcode già compilato; l'utente può completarla oppure annullare.

La stampa delle etichette è isolata dietro `ILabelPrinter`, in modo da poter implementare backend differenti (driver Windows, CUPS/Linux o protocollo diretto della stampante) senza cambiare il resto del gestionale.
