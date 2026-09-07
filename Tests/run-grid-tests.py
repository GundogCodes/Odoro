#!/usr/bin/env python3
"""Compile the actual app and widget models separately and run the same regressions.
Run: python3 Tests/run-grid-tests.py
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
tests = (root / 'Tests/GridProgressTests.swift').read_text()
for source, end_marker in [
    ('Odoro/TrackerView.swift', '// MARK: - Icon Catalog'),
    ('OdoroWidgetExtension/HabitWidgetShared.swift', '// MARK: - Data Store'),
]:
    model = (root / source).read_text().split(end_marker)[0]
    extra = ''
    if source.startswith('OdoroWidgetExtension/'):
        entries = (root / 'OdoroWidgetExtension/HabitWidgets.swift').read_text().split('// MARK: - Timeline Provider with Intent')[0]
        schedule = (root / 'OdoroWidgetExtension/CyclingHabitWidget.swift').read_text().split('struct CyclingHabitWidgetProvider')[0]
        extra = entries + '\n' + schedule + '\n' + (root / 'Tests/CyclingWidgetTests.swift').read_text()
    with tempfile.TemporaryDirectory(prefix='odoro-grid-tests-') as directory:
        path = Path(directory)
        (path / 'main.swift').write_text(model + '\n' + tests + '\n' + extra)
        subprocess.run(['swiftc', '-module-cache-path', str(path / 'cache'),
                        str(path / 'main.swift'), '-o', str(path / 'tests')], check=True)
        print(source, flush=True)
        subprocess.run([str(path / 'tests')], check=True)
