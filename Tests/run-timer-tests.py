#!/usr/bin/env python3
"""Exercise the actual Timer view calculations in the app and widget.
Only Swift access modifiers are removed in the temporary test harness.
Run: python3 Tests/run-timer-tests.py
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
for widget in [False, True]:
    model_path = 'OdoroWidgetExtension/HabitWidgetShared.swift' if widget else 'Odoro/TrackerView.swift'
    model_end = '// MARK: - Data Store' if widget else '// MARK: - Icon Catalog'
    model = (root / model_path).read_text().split(model_end)[0]
    source = (root / ('OdoroWidgetExtension/HabitWidgets.swift' if widget else 'Odoro/TrackerView.swift')).read_text()
    start = 'struct WidgetTextCounterView' if widget else 'struct TextCounterView'
    end = 'struct WidgetTimelineBarView' if widget else '// MARK: - Timeline Bar View'
    view = source[source.index(start):source.index(end)].replace('private ', '')
    constructor = 'WidgetTextCounterView(habit: habit, family: .systemSmall)' if widget else 'TextCounterView(habit: habit)'
    test = '''
import WidgetKit
import AppKit
@MainActor
func verifyTimer() throws {
    let json = Data("{\\"id\\":\\"A1B2C3D4-E5F6-7890-ABCD-EF1234567890\\",\\"name\\":\\"Reading Timer\\"}".utf8)
    var habit = try JSONDecoder().decode(Habit.self, from: json)
    habit.visualStyle = .text
    habit.widgetSize = .fullMedium
    habit.createdAt = Date().addingTimeInterval(-116 * 86400)
    habit.durationType = .indefinite
    habit.type = .countdown
    habit.targetDate = Date().addingTimeInterval(-3 * 86400)
    var view = CONSTRUCTOR
    precondition(!view.isCountingDown, "Indefinite timer always measures elapsed time")
    precondition(abs(view.timeInterval - 116 * 86400) < 10, "Indefinite ignores stale target and duration")
    habit.lastResetDate = Date().addingTimeInterval(-3600)
    view = CONSTRUCTOR
    precondition(abs(view.timeInterval - 3600) < 10, "Indefinite timer respects reset")
    habit.durationType = .toTargetDate
    habit.targetDate = Date().addingTimeInterval(7200)
    view = CONSTRUCTOR
    precondition(view.isCountingDown && abs(view.timeInterval - 7200) < 10, "Target-date countdown remains correct")
    habit.durationType = .customRange
    habit.textCounterDuration = 4
    habit.timeUnit = .hours
    view = CONSTRUCTOR
    precondition(abs(view.timeInterval - 3 * 3600) < 10, "Custom countdown uses duration, not stale target")
    habit.type = .countUp
    habit.durationType = .indefinite
    habit.lastResetDate = nil
    habit.timeUnit = .days
    view = CONSTRUCTOR
    let renderer = ImageRenderer(content: view.frame(width: 350, height: 160).background(Color.black).environment(\.colorScheme, .dark))
    renderer.scale = 2
    if let cgImage = renderer.cgImage {
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "OUTPUT"))
    }
    print("Passed indefinite Timer, reset, target-date and custom countdown checks")
}
try MainActor.assumeIsolated { try verifyTimer() }
'''.replace('CONSTRUCTOR', constructor).replace('OUTPUT', '/tmp/odoro-indefinite-' + ('widget' if widget else 'app') + '.png')
    with tempfile.TemporaryDirectory(prefix='odoro-timer-tests-') as directory:
        path = Path(directory)
        (path / 'main.swift').write_text(model + '\n' + view + '\n' + test)
        subprocess.run(['swiftc', '-module-cache-path', str(path / 'cache'), str(path / 'main.swift'), '-o', str(path / 'tests')], check=True)
        print(model_path, flush=True)
        subprocess.run([str(path / 'tests')], check=True)
