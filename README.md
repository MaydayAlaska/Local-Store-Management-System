# Local Store Management System

Gestionale desktop multipiattaforma per negozio, pensato per funzionare **offline** su Windows e Linux.

## Stack

- .NET 10 LTS
- Avalonia UI 12.1.1
- SQLite tramite `Microsoft.Data.Sqlite`
- Architettura desktop nativa: **nessun browser e nessun server web richiesto**

## Roadmap funzionale

1. **Prodotti**
   - SKU/codice interno e barcode;
   - nome, marca e categoria;
   - **variante e taglia come attributi distinti**;
   - prezzo di acquisto e prezzo di vendita;
   - note e stato attivo/disattivato;
   - nessuna scorta minima.
2. **Magazzino**
   - carico, scarico e rettifica;
   - storico di ogni movimento;
   - giacenza calcolata dai movimenti e non modificata direttamente nella scheda prodotto.
3. **Scanner**
   - lettura HID/tastiera;
   - ricerca immediata del prodotto;
   - proposta di creazione quando il codice non esiste;
   - modalità carico/scarico veloce.
4. **Etichette**
   - generazione barcode;
   - anteprima e numero copie;
   - stampa ApiX110 tramite backend separati Windows/Linux.
5. **Backup ed esportazione**
   - backup del database SQLite;
   - esportazione Excel completa di tutto il magazzino, raggruppata per marca e con marche in ordine alfabetico;
   - esportazione Excel parziale filtrando una o più marche e/o una o più categorie;
   - build e pacchetti per Windows e Linux.

Non è previsto un modulo separato di inventario fisico/conteggio sessione.

## Stato attuale (`test`)

Il modulo **Prodotti v1** contiene l'anagrafica completa, ricerca e modifica. La quantità mostrata deriva dalla somma dei movimenti di magazzino; il modulo di carico/scarico verrà implementato nel passaggio successivo.

## Struttura

```text
src/LocalStoreManagement.Desktop/
├── Data/                 # accesso SQLite e repository
├── Infrastructure/       # database, migrazioni e percorsi locali
├── Models/               # modelli applicativi
├── Services/             # contratti hardware e servizi applicativi
├── App.axaml             # bootstrap Avalonia
├── MainWindow.axaml      # shell desktop
└── LocalStoreManagement.Desktop.csproj
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

Lo scanner di codici a barre viene trattato come dispositivo HID/tastiera: il codice scansionato termina con `Enter` e viene acquisito dal campo di scansione dell'applicazione.

La stampa delle etichette è isolata dietro `ILabelPrinter`, in modo da poter implementare backend differenti (driver Windows, CUPS/Linux o protocollo diretto della stampante) senza cambiare il resto del gestionale.
