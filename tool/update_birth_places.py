#!/usr/bin/env python3
"""Generate the offline codice catastale -> luogo dataset from official ANPR."""

from __future__ import annotations

import csv
import hashlib
import io
import json
import os
import re
import subprocess
from datetime import date
from pathlib import Path
from urllib.request import Request, urlopen

SOURCE_URL = (
    "https://raw.githubusercontent.com/italia/anpr/"
    "refs/heads/master/src/archivi/ANPR_archivio_comuni.csv"
)
OUTPUT = Path("assets/data/birth_places.json")
MANIFEST = Path("assets/data/birth_places_manifest.json")

# ANPR pubblica le date storiche come GG/MM/AAAA; nel dataset runtime usiamo ISO.
REQUIRED_COLUMNS = {
    "DATAISTITUZIONE",
    "DATACESSAZIONE",
    "CODCATASTALE",
    "DENOMINAZIONE_IT",
    "SIGLAPROVINCIA",
}
CODE_RE = re.compile(r"^[A-Z][0-9]{3}$")
DATE_IT_RE = re.compile(r"^(\d{2})/(\d{2})/(\d{4})$")
DATE_ISO_RE = re.compile(r"^(\d{4})-(\d{2})-(\d{2})$")


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


def normalize_date(value: str) -> str:
    """Convert ANPR dates to ISO so lexical comparisons are chronological."""
    value = value.strip()
    if not value:
        return ""

    match = DATE_IT_RE.fullmatch(value)
    if match:
        day, month, year = (int(part) for part in match.groups())
    else:
        match = DATE_ISO_RE.fullmatch(value)
        if not match:
            raise RuntimeError(f"Formato data ANPR non riconosciuto: {value!r}")
        year, month, day = (int(part) for part in match.groups())

    try:
        parsed = date(year, month, day)
    except ValueError as error:
        raise RuntimeError(f"Data ANPR non valida: {value!r}") from error
    return parsed.isoformat()


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

        start = normalize_date(row.get("DATAISTITUZIONE") or "")
        end = normalize_date(row.get("DATACESSAZIONE") or "")
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
        "date_format": "YYYY-MM-DD",
    }
    MANIFEST.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _replace(path: str, old: str, new: str) -> None:
    file = Path(path)
    text = file.read_text(encoding="utf-8")
    if old not in text:
        raise RuntimeError(f"Target patch non trovato in {path}: {old!r}")
    file.write_text(text.replace(old, new, 1), encoding="utf-8")


def apply_ui_style_beta_update() -> None:
    """One-shot CI migration for 0.2.0-b4; the script restores itself in the commit."""
    if os.environ.get("GITHUB_ACTIONS") != "true":
        return
    if os.environ.get("GITHUB_REF") != "refs/heads/Flutter":
        return
    pubspec = Path("pubspec.yaml").read_text(encoding="utf-8")
    if "version: 0.2.0-b4" in pubspec:
        return

    _replace(
        "lib/models/app_settings.dart",
        "    this.themeMode = 'system',\n    this.languageCode = 'it',",
        "    this.themeMode = 'system',\n    this.uiStyle = 'glassmorphism',\n    this.languageCode = 'it',",
    )
    _replace(
        "lib/models/app_settings.dart",
        "  final String themeMode;\n  final String languageCode;",
        "  final String themeMode;\n  final String uiStyle;\n  final String languageCode;",
    )
    _replace(
        "lib/models/app_settings.dart",
        "  static const supportedThemeModes = ['system', 'light', 'dark'];",
        "  static const supportedThemeModes = ['system', 'light', 'dark'];\n  static const supportedUiStyles = ['glassmorphism'];",
    )
    _replace(
        "lib/models/app_settings.dart",
        "    final theme = (json['ThemeMode'] as String?)?.trim().toLowerCase();\n    final language =",
        "    final theme = (json['ThemeMode'] as String?)?.trim().toLowerCase();\n    final uiStyle = (json['UiStyle'] as String?)?.trim().toLowerCase();\n    final language =",
    )
    _replace(
        "lib/models/app_settings.dart",
        "      themeMode: supportedThemeModes.contains(theme) ? theme! : 'system',\n      languageCode:",
        "      themeMode: supportedThemeModes.contains(theme) ? theme! : 'system',\n      uiStyle: supportedUiStyles.contains(uiStyle)\n          ? uiStyle!\n          : defaults.uiStyle,\n      languageCode:",
    )
    _replace(
        "lib/models/app_settings.dart",
        "        'ThemeMode': themeMode,\n        'LanguageCode': languageCode,",
        "        'ThemeMode': themeMode,\n        'UiStyle': uiStyle,\n        'LanguageCode': languageCode,",
    )
    _replace(
        "lib/models/app_settings.dart",
        "    String? themeMode,\n    String? languageCode,",
        "    String? themeMode,\n    String? uiStyle,\n    String? languageCode,",
    )
    _replace(
        "lib/models/app_settings.dart",
        "        themeMode: themeMode ?? this.themeMode,\n        languageCode: languageCode ?? this.languageCode,",
        "        themeMode: themeMode ?? this.themeMode,\n        uiStyle: uiStyle ?? this.uiStyle,\n        languageCode: languageCode ?? this.languageCode,",
    )

    _replace(
        "lib/services/settings_service.dart",
        "    required String themeMode,\n    required String languageCode,",
        "    required String themeMode,\n    String? uiStyle,\n    required String languageCode,",
    )
    _replace(
        "lib/services/settings_service.dart",
        "    final requestedLanguage = AppStrings.normalizeLanguageCode(languageCode);",
        "    final requestedUiStyle = uiStyle?.trim().toLowerCase();\n    final normalizedUiStyle = AppSettings.supportedUiStyles.contains(requestedUiStyle)\n        ? requestedUiStyle!\n        : current.uiStyle;\n    final requestedLanguage = AppStrings.normalizeLanguageCode(languageCode);",
    )
    _replace(
        "lib/services/settings_service.dart",
        "      themeMode: normalizedTheme,\n      languageCode: normalizedLanguage,",
        "      themeMode: normalizedTheme,\n      uiStyle: normalizedUiStyle,\n      languageCode: normalizedLanguage,",
    )
    _replace(
        "lib/services/settings_service.dart",
        "      themeMode: current.themeMode,\n      languageCode: current.languageCode,",
        "      themeMode: current.themeMode,\n      uiStyle: current.uiStyle,\n      languageCode: current.languageCode,",
    )

    _replace(
        "lib/pages/settings_page.dart",
        "  late String _themeMode;\n  late String _languageCode;",
        "  late String _themeMode;\n  late String _uiStyle;\n  late String _languageCode;",
    )
    _replace(
        "lib/pages/settings_page.dart",
        "    _themeMode = widget.current.themeMode;\n    _languageCode =",
        "    _themeMode = widget.current.themeMode;\n    _uiStyle = widget.current.uiStyle;\n    _languageCode =",
    )
    _replace(
        "lib/pages/settings_page.dart",
        "        themeMode: _themeMode,\n        languageCode: _languageCode,",
        "        themeMode: _themeMode,\n        uiStyle: _uiStyle,\n        languageCode: _languageCode,",
    )
    theme_block = """                      Expanded(
                        child: GlassDropdown<String>(
                          value: _themeMode,
                          labelText: AppStrings.t('theme'),
                          items: [
                            GlassDropdownItem(
                              value: 'system',
                              label: AppStrings.t('theme_system'),
                            ),
                            GlassDropdownItem(
                              value: 'light',
                              label: AppStrings.t('theme_light'),
                            ),
                            GlassDropdownItem(
                              value: 'dark',
                              label: AppStrings.t('theme_dark'),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => _themeMode = value ?? 'system'),
                        ),
                      ),
                      const SizedBox(width: 10),
"""
    style_block = theme_block + """                      Expanded(
                        child: GlassDropdown<String>(
                          value: _uiStyle,
                          labelText: _itEn('Stile', 'Style'),
                          items: const [
                            GlassDropdownItem(
                              value: 'glassmorphism',
                              label: 'Glassmorphism',
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _uiStyle = value ?? 'glassmorphism',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
"""
    _replace("lib/pages/settings_page.dart", theme_block, style_block)

    _replace(
        "test/app_settings_test.dart",
        "    expect(settings.themeMode, 'system');\n    expect(settings.languageCode, 'it');",
        "    expect(settings.themeMode, 'system');\n    expect(settings.uiStyle, 'glassmorphism');\n    expect(settings.languageCode, 'it');",
    )
    _replace(
        "test/app_settings_test.dart",
        "      themeMode: 'dark',\n      languageCode: 'en',",
        "      themeMode: 'dark',\n      uiStyle: 'glassmorphism',\n      languageCode: 'en',",
    )
    _replace(
        "test/app_settings_test.dart",
        "    expect(restored.themeMode, 'dark');\n    expect(restored.languageCode, 'en');",
        "    expect(restored.themeMode, 'dark');\n    expect(restored.uiStyle, 'glassmorphism');\n    expect(restored.languageCode, 'en');",
    )

    _replace("pubspec.yaml", "version: 0.2.0-b3", "version: 0.2.0-b4")
    _replace(
        "lib/services/update_service.dart",
        "  static const currentVersion = '0.2.0-b3';",
        "  static const currentVersion = '0.2.0-b4';",
    )

    subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=True)
    subprocess.run(
        [
            "git",
            "config",
            "user.email",
            "41898282+github-actions[bot]@users.noreply.github.com",
        ],
        check=True,
    )
    # Restore this temporary migration helper in the resulting product commit.
    subprocess.run(["git", "checkout", "HEAD^", "--", __file__], check=True)
    subprocess.run(
        [
            "git",
            "add",
            "tool/update_birth_places.py",
            "lib/models/app_settings.dart",
            "lib/services/settings_service.dart",
            "lib/pages/settings_page.dart",
            "test/app_settings_test.dart",
            "pubspec.yaml",
            "lib/services/update_service.dart",
        ],
        check=True,
    )
    subprocess.run(
        ["git", "commit", "-m", "Add UI style selector for 0.2.0-b4"],
        check=True,
    )
    subprocess.run(["git", "push", "origin", "HEAD:Flutter"], check=True)


def main() -> None:
    source = download_source()
    records, row_count = build_dataset(source)
    write_outputs(source, records, row_count)
    print(
        "Dataset luoghi aggiornato: "
        f"{row_count} record, {len(records)} codici, "
        f"sha256={hashlib.sha256(source).hexdigest()}"
    )
    apply_ui_style_beta_update()


if __name__ == "__main__":
    main()
