# Versioning

Il progetto usa versioni nel formato semplice `X.Y.Z`, senza build metadata con `+`.

- `main` contiene le versioni stabili e pubblica tag leggibili `vX.Y.Z`.
- `Flutter` è il branch BETA/TEST principale: le build ricevono `BUILD_BRANCH=Flutter`, mostrano `BETA` nell'app e non possono installare il canale OTA stabile.
- I push su `Flutter` pubblicano la prerelease `flutter-latest` con i pacchetti di test per Windows e Linux, x64 e ARM64.
- Il branch `test` resta compatibile come eventuale canale BETA legacy e continua a essere riconosciuto dall'app come build di test.
- Le release di `main` ricevono il commit tramite `GIT_COMMIT` e mantengono il bridge tecnico `ota-<sha>` necessario all'aggiornamento automatico.
- Quando viene preparata una nuova versione pubblica si incrementa direttamente `X`, `Y` o `Z`; non viene più mantenuto un build number separato.

Versione corrente: `0.1.4`.
