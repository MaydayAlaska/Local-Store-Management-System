# Traduzioni / Translations

Dalla versione `0.1.7-b1` le traduzioni dell'interfaccia non sono più memorizzate nella mappa Dart di `AppStrings`: vengono caricate da file JSON separati.

## Dove si trovano

I file inclusi nel progetto sono:

```text
assets/translations/it.json
assets/translations/en.json
```

All'avvio l'applicazione copia le lingue incluse nella cartella dati dell'utente:

```text
Documenti/Local Store Management System/Translations/
```

Nella stessa cartella è possibile aggiungere altri file `.json`. I file aggiunti dall'utente non vengono eliminati dall'applicazione. `it.json` ed `en.json` vengono invece riallineati alla versione inclusa nell'app per garantire che le lingue ufficiali contengano sempre tutte le chiavi richieste.

## Creare una nuova lingua

1. Copiare `it.json` oppure `en.json` con un nuovo nome, per esempio `fr.json`.
2. Impostare `languageCode` con il codice della lingua, per esempio `fr` oppure `pt-br`.
3. Impostare `languageName` con il **nome nativo della lingua**, per esempio `Français`, `Deutsch`, `Español`. Il nome non deve essere tradotto in base alla lingua corrente dell'app.
4. Lasciare `schemaVersion` invariato.
5. Tradurre **tutti i valori** dell'oggetto `strings`, senza modificare le chiavi.
6. Riavviare l'applicazione.

Esempio minimo di struttura:

```json
{
  "languageCode": "fr",
  "languageName": "Français",
  "schemaVersion": 1,
  "strings": {
    "dashboard": "Tableau de bord"
  }
}
```

Il file reale deve contenere tutte le chiavi presenti nella lingua italiana di riferimento. Se mancano chiavi obbligatorie, la lingua viene ignorata e non compare nel selettore delle Impostazioni; il file resta comunque nella cartella e può essere corretto.

## Segnaposto

Le stringhe possono usare segnaposto nel formato `{nome}`. I nomi tra parentesi graffe non devono essere tradotti. Per esempio:

```json
"example": "Cliente {name}"
```

## Compatibilità con stringhe legacy

Durante la migrazione completa delle schermate più vecchie è supportato anche un oggetto facoltativo `legacy`. Le sue chiavi sono il testo inglese di riferimento usato dalle vecchie schermate e i valori sono la traduzione nella lingua del file:

```json
{
  "legacy": {
    "Add label printer": "Ajouter une imprimante d’étiquettes"
  }
}
```

Le nuove stringhe non devono usare `legacy`: devono avere una chiave stabile nell'oggetto `strings`.

## Regole

- codifica file: UTF-8;
- formato: JSON valido;
- `languageCode` deve essere univoco;
- `languageName` deve essere il nome nativo della lingua;
- non rimuovere o rinominare chiavi esistenti;
- mantenere invariati i segnaposto `{...}`;
- una traduzione incompleta non viene resa selezionabile.
