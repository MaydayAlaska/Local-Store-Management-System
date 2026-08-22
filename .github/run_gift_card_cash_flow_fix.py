from pathlib import Path
import subprocess

source_path = Path('.github/implement_optional_gift_card_owner.py')
source = source_path.read_text()
old = "new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S | re.M)"
new = "new_text, count = re.subn(pattern, lambda _match: replacement, text, count=1, flags=re.S | re.M)"
if source.count(old) != 1:
    raise SystemExit('Unable to patch regex_once replacement handling')
fixed = source.replace(old, new, 1)
target = Path('/tmp/implement_gift_card_cash_flow.py')
target.write_text(fixed)
subprocess.run(['python3', '-m', 'py_compile', str(target)], check=True)
subprocess.run(['python3', str(target)], check=True)
