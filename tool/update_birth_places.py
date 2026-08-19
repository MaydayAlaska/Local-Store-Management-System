#!/usr/bin/env python3
"""Generate the offline codice catastale -> luogo dataset from official ANPR."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import re
from pathlib import Path
from urllib.request import Request, urlopen

SOURCE_URL = (
    "https://raw.githubusercontent.com/italia/anpr/"
    "refs/heads/master/src/archivi/ANPR_archivio_comuni.csv"
)
OUTPUT = Path("assets/data/birth_places.json")
MANIFEST = Path("assets/data/birth_places_manifest.json")

REQUIRED_COLUMNS = {
    "DATAISTITUZIONE",
    "DATACESSAZIONE",
    "CODCATASTALE",
    "DENOMINAZIONE_IT",
    "SIGLAPROVINCIA",
}
CODE_RE = re.compile(r"^[A-Z][0-9]{3}$")


def download_source() -> bytes:
    request = Request(
        SOURCE_URL,
        headers={
            "User-Agent": "Local-Store-Management-System birth-place updater",
            "Accept": "text/csv,text/plain,*/*",
        },
    )
    with urlopen(request, timeout=60) as response:
        data = response.read()
    if len(data) < 1_000_000:
        raise RuntimeError(
            f"Archivio ANPR insolitamente piccolo ({len(data)} byte): aggiornamento bloccato."
        )
    return data


def build_dataset(source: bytes) -> tuple[dict[str, list[list[str]]], int]:
    text = source.decode("utf-8-sig")
    reader = csv.DictReader(io.StringIO(text), delimiter=",")
    fieldnames = set(reader.fieldnames or [])
    missing = REQUIRED_COLUMNS - fieldnames
    if missing:
        raise RuntimeError(
            "Formato ANPR cambiato; colonne mancanti: " + ", ".join(sorted(missing))
        )

    records: dict[str, list[list[str]]] = {}
    row_count = 0
    for row in reader:
        code = (row.get("CODCATASTALE") or "").strip().upper()
        name = (row.get("DENOMINAZIONE_IT") or "").strip()
        if not CODE_RE.fullmatch(code) or not name:
            continue

        start = (row.get("DATAISTITUZIONE") or "").strip()
        end = (row.get("DATACESSAZIONE") or "").strip()
        province = (row.get("SIGLAPROVINCIA") or "").strip().upper()
        records.setdefault(code, []).append([start, end, name, province])
        row_count += 1

    for values in records.values():
        values.sort(key=lambda value: (value[0], value[1], value[2], value[3]))

    if row_count < 10_000 or len(records) < 7_000:
        raise RuntimeError(
            "Archivio ANPR incompleto: "
            f"{row_count} righe valide, {len(records)} codici unici."
        )

    roma = records.get("H501", [])
    if not any(value[2].strip().upper() == "ROMA" for value in roma):
        raise RuntimeError("Controllo di integrità fallito: H501 non risolve ROMA.")

    return dict(sorted(records.items())), row_count


def write_outputs(source: bytes, records: dict[str, list[list[str]]], row_count: int) -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(
        records,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    OUTPUT.write_text(encoded + "\n", encoding="utf-8")

    manifest = {
        "schema_version": 1,
        "source": "ANPR - Anagrafe Nazionale della Popolazione Residente",
        "source_url": SOURCE_URL,
        "source_sha256": hashlib.sha256(source).hexdigest(),
        "source_size_bytes": len(source),
        "record_count": row_count,
        "code_count": len(records),
    }
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    source = download_source()
    records, row_count = build_dataset(source)
    write_outputs(source, records, row_count)
    print(
        "Dataset luoghi aggiornato: "
        f"{row_count} record, {len(records)} codici, "
        f"sha256={hashlib.sha256(source).hexdigest()}"
    )


if __name__ == "__main__":
    main()
