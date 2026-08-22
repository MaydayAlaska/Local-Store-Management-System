# Versioning

Il progetto usa versioni stabili nel formato `X.Y.Z`, senza build metadata con `+`.

Le versioni BETA usano sempre il formato `X.Y.Z-bN`, per esempio `0.1.9-b1`. Lo stesso formato viene utilizzato nel `pubspec.yaml`, nell'interfaccia, nelle release e nei nomi dei pacchetti.

- `main` contiene le versioni stabili e pubblica tag leggibili `vX.Y.Z`.
- `Flutter` è il branch BETA/TEST principale: le nuove modifiche vengono validate qui prima della promozione su `main`.
- Le build di `Flutter` ricevono `BUILD_BRANCH=Flutter`, mostrano `BETA` nell'applicazione e usano esclusivamente il canale OTA BETA.
- I push su `Flutter` pubblicano la prerelease `beta-latest` con pacchetti BETA per Windows, macOS e Linux, x64 e ARM64.
- Il canale OTA BETA accetta esclusivamente versioni `X.Y.Z-bN` e rifiuta versioni stabili `X.Y.Z`.
- Le build di `main` usano esclusivamente il canale OTA STABLE e rifiutano qualunque versione con suffisso `-bN`.
- Le release stabili mantengono il tag pubblico `vX.Y.Z` e il bridge tecnico `ota-<sha>` usato dall'aggiornamento automatico.
- `pubspec.yaml` e `UpdateService.currentVersion` devono sempre contenere la stessa versione; la CI verifica automaticamente questa coerenza.
- L'OTA confronta le versioni in modo monotono: un aggiornamento viene proposto solo quando la versione online è realmente successiva a quella installata. Un commit differente, da solo, non è sufficiente.
- A parità di `X.Y.Z`, una release stabile è semanticamente successiva a qualunque Beta della stessa versione, ma i canali STABLE e BETA non vengono mai incrociati dall'OTA.
- Durante un ciclo Beta si incrementa `bN`: `0.1.9-b1` → `0.1.9-b2` → `0.1.9-b3` e così via.
- Quando una Beta viene promossa, `main` riceve la versione stabile senza suffisso e `Flutter` avanza alla prima Beta del ciclo successivo, salvo prosecuzione esplicita di un ciclo Beta di manutenzione.
- `avalonia` contiene la precedente implementazione Avalonia ed è un ramo storico/alternativo.

Versione stabile corrente su `main`: `0.1.9`.

Versione BETA corrente su `Flutter`: `0.1.9-b2`.
