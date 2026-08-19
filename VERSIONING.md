# Versioning

Il progetto usa versioni stabili nel formato semplice `X.Y.Z`, senza build metadata con `+`.

Le versioni BETA usano invece la forma leggibile `X.Y.Z.bN` (per esempio `0.1.5.b1`). Poiché `pubspec.yaml` richiede una versione SemVer valida, la stessa Beta viene dichiarata internamente come `X.Y.Z-bN` (per esempio `0.1.5-b1`).

- `main` contiene le versioni stabili e pubblica tag leggibili `vX.Y.Z`.
- `Flutter` è il branch BETA/TEST principale: le build ricevono `BUILD_BRANCH=Flutter`, mostrano `BETA` nell'app e non possono installare il canale OTA stabile.
- I push su `Flutter` pubblicano la prerelease `flutter-latest` con i pacchetti di test per Windows e Linux, x64 e ARM64.
- Il branch `test` resta compatibile come eventuale canale BETA legacy e continua a essere riconosciuto dall'app come build di test.
- Le release di `main` ricevono il commit tramite `GIT_COMMIT` e mantengono il bridge tecnico `ota-<sha>` necessario all'aggiornamento automatico.
- Durante il ciclo di test si incrementa il suffisso Beta (`b1`, `b2`, `b3`, ...). Quando la versione viene promossa a stabile, il suffisso Beta viene rimosso.

Versione BETA corrente: `0.1.5.b1` (`0.1.5-b1` in `pubspec.yaml`).
