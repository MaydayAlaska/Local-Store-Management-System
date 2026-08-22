from pathlib import Path
import subprocess

source_path = Path('.github/implement_optional_gift_card_owner.py')
source = source_path.read_text()

old_regex = "new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)"
new_regex = "new_text, count = re.subn(pattern, lambda _match: replacement, text, count=1, flags=re.S | re.M)"
if source.count(old_regex) != 1:
    raise SystemExit('Unable to patch regex_once replacement handling')
fixed = source.replace(old_regex, new_regex, 1)

# Double the three Dart newline escapes before Python parses the helper.
for old, new in (
    ("${card.spentDisplay}\\n'", "${card.spentDisplay}\\\\n'"),
    ("$expiration'}\\n'", "$expiration'}\\\\n'"),
    ("Remaining')}\\n${card.remainingDisplay}'", "Remaining')}\\\\n${card.remainingDisplay}'"),
):
    if fixed.count(old) != 1:
        raise SystemExit(f'Unable to patch Dart line break: {old!r}')
    fixed = fixed.replace(old, new, 1)

target = Path('/tmp/implement_gift_card_cash_flow.py')
target.write_text(fixed)
subprocess.run(['python3', '-m', 'py_compile', str(target)], check=True)
subprocess.run(['python3', str(target)], check=True)
