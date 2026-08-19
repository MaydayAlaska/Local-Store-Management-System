# Versioning

Il progetto usa versioni stabili nel formato semplice `X.Y.Z`, senza build metadata con `+`.

Le versioni BETA usano sempre il formato `X.Y.Z-bN` (per esempio `0.1.6-b1`). Questa è l'unica forma usata nel `pubspec.yaml`, nell'interfaccia, nei nomi delle release e nei nomi dei pacchetti.

- `main` contiene le versioni stabili e pubblica tag leggibili `vX.Y.Z`.
- `Flutter` è il branch BETA/TEST principale: tutte le nuove modifiche vengono validate qui prima della promozione su `main`.
- Le build di `Flutter` ricevono `BUILD_BRANCH=Flutter`, mostrano `BETA` nell'app e usano esclusivamente il canale OTA BETA.
- I push su `Flutter` pubblicano la prerelease `beta-latest` con pacchetti BETA per Windows, macOS e Linux, x64 e ARM64.
- Le build stabili di `main` usano esclusivamente il canale OTA stabile e non installano prerelease BETA.
- Le release di `main` ricevono il commit tramite `GIT_COMMIT` e mantengono il bridge tecnico `ota-<sha>` necessario all'aggiornamento automatico.
- L'OTA confronta le versioni in modo monotono: un aggiornamento viene proposto solo quando la versione online è realmente successiva a quella installata. Un commit differente, da solo, non è sufficiente.
- A parità di `X.Y.Z`, una release stabile è successiva a qualunque Beta della stessa versione: `0.1.5 > 0.1.5-b99`.
- Dopo la promozione di una Beta a stabile, `main` mantiene la versione stabile e `Flutter` passa alla prima Beta della versione successiva.
- `avalonia` contiene la precedente implementazione Avalonia ed è un ramo storico/alternativo.

Versione stabile corrente su `main`: `0.1.5`.

Versione BETA corrente su `Flutter`: `0.1.6-b1`.
