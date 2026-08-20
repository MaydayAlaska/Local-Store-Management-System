# Local Store Management System

Gestionale desktop **offline** per negozi, sviluppato in **Flutter/Dart** con database locale **SQLite**.

La versione stabile corrente è **0.1.6** sul branch `main`.

Il branch `Flutter` resta il canale **BETA/TEST** e mantiene la versione **0.1.6-b15**. I due canali OTA sono separati: le build stabili ricevono solo release stabili e le build Beta ricevono solo prerelease Beta.

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

- catalogo prodotti e varianti con SKU, barcode, prezzi e giacenze;
- magazzino con movimenti di carico/scarico;
- cassa con scanner HID, ricerca prodotti, tastierino numerico, sconti e cliente associato;
- clienti con codice identificativo interno univoco e riutilizzabile dopo l'eliminazione;
- codice fiscale cliente facoltativo, ma univoco quando presente, inseribile anche successivamente;
- storico acquisti del cliente e gestione ordini/vendite;
- buoni regalo associati ai clienti con codice univoco, valore totale, valore speso e residuo calcolato;
- utilizzo parziale o totale dei buoni regalo direttamente in cassa;
- annullamento vendite con ripristino della merce e, quando previsto, del credito del buono regalo;
- eliminazione singola degli ordini e pulizia degli ordini più vecchi di un intervallo configurabile;
- etichette con anteprima, EAN-13, Code 128 B e stampa diretta TCP/BPL-Z;
- export inventario Excel/PDF, backup e impostazioni applicazione;
- interfaccia in Italiano e English, tema chiaro/scuro/sistema e valuta configurabile;
- aggiornamenti OTA separati tra canale stabile e canale Beta.

## Novità della 0.1.6

La 0.1.6 promuove in stabile il ciclo Beta `0.1.6-b1` → `0.1.6-b15`.

### Clienti e buoni regalo

Ogni cliente possiede un codice identificativo `CLI-XXXXXX` indipendente dall'ID interno del database. Il codice fiscale non è più obbligatorio e può essere aggiunto o modificato successivamente; se presente rimane univoco.

Quando un cliente viene eliminato, il suo codice identificativo torna disponibile e può essere riutilizzato senza ricollegare per errore gli ordini storici a un nuovo cliente.

I buoni regalo:

- sono associati a un cliente;
- hanno un codice univoco;
- memorizzano **valore totale** e **valore speso**;
- calcolano il residuo come `totale - speso`;
- possono essere eliminati;
- possono essere usati in cassa solo dopo aver associato il relativo cliente;
- possono coprire interamente o parzialmente il totale da pagare.

Il buono viene trattato come metodo di pagamento e non come sconto: il valore reale della vendita resta invariato nello storico e nella fiscalità, mentre diminuisce il totale ancora da pagare.

### Cassa

La Cassa include il tastierino numerico per l'inserimento di articoli generici. Il tastierino può essere mostrato o nascosto tramite un pulsante dedicato, restituendo spazio al carrello quando non serve.

I comandi principali sono disposti come tre pulsanti larghi e compatti:

- **Registra vendita**;
- **Emetti scontrino**;
- **Nascondi tastierino / Mostra tastierino**.

### Vendite e ordini

Le vendite possono essere annullate: l'ordine rimane nello storico come **ANNULLATO**, la merce viene restituita alla giacenza e l'eventuale credito di un buono regalo utilizzato viene ripristinato.

È inoltre possibile eliminare definitivamente un ordine. L'eliminazione non modifica il magazzino né il credito dei buoni: per ripristinare gli effetti di una vendita occorre prima annullarla.

La sezione Vendite permette anche di eliminare in blocco gli ordini più vecchi di un intervallo espresso in giorni, mesi o anni.

### Interfaccia

I menu a tendina seguono il tema grafico dell'applicazione. Il popup per l'eliminazione degli ordini vecchi utilizza il componente `GlassDropdown`, mentre la tematizzazione globale copre anche gli altri menu Material.

Nell'elenco Clienti viene mostrato sotto al nome soltanto il codice fiscale, quando presente; il codice `CLI-XXXXXX` rimane disponibile nella scheda dettagli del cliente.

I nomi delle lingue vengono sempre mostrati nella loro forma nativa: **Italiano** e **English**.

### Altre modifiche del ciclo 0.1.6

- valuta persistente: EUR, USD, GBP o CHF;
- tema sistema, chiaro o scuro;
- menu laterale scorrevole quando necessario;
- controlli finestra e interfaccia desktop rifiniti;
- esportazione inventario con scelta delle colonne;
- nuovi SKU generati in formato esadecimale;
- generazione SKU univoco dal popup prodotto/variante;
- supporto macOS Intel e Apple Silicon con pacchetto `.dmg` contenente l'app;
- integrazione stampa etichette diretta via TCP socket;
- gestione del codice luogo del codice fiscale e dataset ANPR verificato in CI;
- separazione rigida tra versioni OTA BETA e STABLE.

## Aggiornamenti OTA

Sono presenti due canali indipendenti:

- `main` → **STABLE**, versioni `X.Y.Z`;
- `Flutter` → **BETA**, versioni `X.Y.Z-bN` e prerelease `beta-latest`.

All'avvio l'app controlla gli aggiornamenti. Un aggiornamento viene proposto solo quando la versione online è realmente superiore a quella installata.

L'updater seleziona automaticamente sistema operativo e architettura. Su Windows installa il nuovo installer, su macOS scarica e apre il DMG, mentre su Linux l'aggiornamento automatico è disponibile quando l'app è stata avviata da AppImage.

## Etichette e stampanti

La sezione Etichette supporta profili stampante persistenti, dimensioni fisiche, anteprima, EAN-13 e Code 128 B.

Per le stampanti di etichette compatibili è disponibile la stampa diretta:

```text
Flutter → TCP socket → stampante:9100 → BPL-Z/ZPL
```

Le dimensioni configurate nell'app vengono utilizzate anche nella stampa diretta, senza dipendere dal driver di stampa di sistema.

## Esportazione inventario

È possibile scegliere i campi da esportare, tra cui prodotto, variante, SKU, barcode, categoria, giacenza, prezzo di acquisto, prezzo di vendita e stato. La selezione viene rispettata sia nell'export Excel sia nel PDF.

I prezzi esportati e visualizzati usano la valuta configurata nelle Impostazioni.

## Impostazioni

Le preferenze di negozio, tema, lingua, valuta, logo, icona e stampanti etichette vengono salvate localmente.

Le lingue disponibili vengono visualizzate con il proprio nome nativo:

- Italiano
- English

## Database

I dati restano localmente in:

```text
Documenti/Local Store Management System/
```

Le migrazioni del database vengono applicate automaticamente per mantenere compatibili anche i database creati dalle versioni precedenti.

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

La CI verifica anche che il dataset ANPR incorporato per i codici luogo sia allineato alla fonte ufficiale corrente.

## CI e release

Strategia branch:

- `main` → STABLE, tag `v<versione>`, OTA stabile;
- `Flutter` → BETA/TEST, prerelease `beta-latest`, OTA Beta;
- `avalonia` → implementazione storica/alternativa.

Ogni push su `main` esegue analisi e test, compila i pacchetti desktop e, se tutto termina correttamente, pubblica automaticamente la release stabile.

Per le regole complete vedere `VERSIONING.md`.
