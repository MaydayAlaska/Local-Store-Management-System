#!/usr/bin/env python3
"""Ensure the main build workflow refuses to publish a stale ANPR dataset."""

from pathlib import Path

BUILD_WORKFLOW = Path('.github/workflows/build.yml')
MARKER = '      - name: Verify embedded ANPR dataset is current\n'
NEEDLE = '      - name: Setup Flutter\n'
STEP = '''      - name: Verify embedded ANPR dataset is current
        shell: bash
        run: |
          set -euo pipefail
          python3 tool/update_birth_places.py
          if ! git diff --quiet -- assets/data/birth_places.json assets/data/birth_places_manifest.json; then
            echo "::error::Il dataset ANPR incorporato non coincide con la fonte ufficiale corrente."
            git diff --stat -- assets/data/birth_places.json assets/data/birth_places_manifest.json
            exit 1
          fi

'''


def main() -> None:
    text = BUILD_WORKFLOW.read_text(encoding='utf-8')
    if MARKER in text:
        print('Guard ANPR gia presente nel workflow di build.')
        return
    if NEEDLE not in text:
        raise RuntimeError('Impossibile trovare il punto di inserimento nel job verify.')
    BUILD_WORKFLOW.write_text(
        text.replace(NEEDLE, STEP + NEEDLE, 1),
        encoding='utf-8',
    )
    print('Guard ANPR aggiunto al workflow di build.')


if __name__ == '__main__':
    main()
