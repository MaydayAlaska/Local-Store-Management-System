# Local Store Management System

Gestionale desktop multipiattaforma per negozio, pensato per funzionare **offline** su Windows e Linux.

## Stack

- .NET 10 LTS
- Avalonia UI 12.1.1
- SQLite tramite `Microsoft.Data.Sqlite`
- Architettura desktop nativa: **nessun browser e nessun server web richiesto**

## Obiettivi

Il progetto gestira progressivamente:

- anagrafica prodotti e codici a barre;
- carico/scarico di magazzino;
- inventario fisico tramite scanner USB/HID;
- storico movimenti;
- stampa di etichette tramite un modulo separato per Windows/Linux;
- backup locale del database.

## Struttura iniziale

```text
src/LocalStoreManagement.Desktop/
├── Infrastructure/       # database, percorsi locali e servizi di sistema
├── Services/             # contratti per scanner/stampante e servizi applicativi
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

La stampa delle etichette e isolata dietro `ILabelPrinter`, in modo da poter implementare backend differenti (driver Windows, CUPS/Linux o protocollo diretto della stampante) senza cambiare il resto del gestionale.
