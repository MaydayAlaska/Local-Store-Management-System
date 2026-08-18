# Versioning

Il progetto Flutter usa la sintassi standard `version: X.Y.Z+W` in `pubspec.yaml`.

- `main` contiene le versioni stabili e pubblica tag leggibili `vX.Y.Z.W`.
- `test` contiene le versioni BETA/TEST e pubblica la prerelease `test-latest`.
- `Flutter` è il branch di sviluppo della migrazione Flutter: viene compilato dalla CI ma non pubblica release automatiche.
- Ogni modifica funzionale o grafica destinata a una nuova build incrementa il build number `W`.
- Esempio: la versione Flutter `0.1.3+10` corrisponde alla numerazione release `0.1.3.10`.
- Le build create da `test` ricevono `BUILD_BRANCH=test`, mostrano `BETA` nell'app e non possono installare il canale OTA stabile.
- Le release di `main` ricevono il commit tramite `GIT_COMMIT` e mantengono il bridge tecnico `ota-<sha>` necessario all'aggiornamento automatico.
