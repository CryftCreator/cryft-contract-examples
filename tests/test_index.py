"""index.json (the code editor's shared-contracts library) lists every example's files with the right sha256."""
import subprocess
import sys

from conftest import ROOT


def test_index_is_in_sync():
    result = subprocess.run([sys.executable, str(ROOT / "tools" / "make_index.py"), "--check"], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr or result.stdout
