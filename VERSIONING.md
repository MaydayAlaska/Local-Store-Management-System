# Versioning

- `main` contiene le versioni stabili e usa tag leggibili `vX.Y.Z.W`.
- `test` contiene le versioni BETA/TEST.
- Ogni modifica funzionale o grafica pubblicata su `test` incrementa l'ultimo numero della versione (es. `0.1.3.1`, `0.1.3.2`, `0.1.3.3`).
- Il suffisso `BETA` viene mostrato dall'app quando `build-info.json` indica il branch `test`.
