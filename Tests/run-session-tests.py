#!/usr/bin/env python3
"""Run the production session clock with notification/audio adapters disabled and in-memory persistence.
No timers, system preferences, or user statistics are changed by this harness.
"""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'Odoro/PomodoroSession.swift').read_text().replace('import UIKit', '')
# Replace platform side effects only; the clock, pause/resume, adjustments and phase logic are unchanged.
for name in ['scheduleTimerEndNotification', 'cancelScheduledNotifications', 'playDingSound']:
    start = source.index('    private func ' + name + '(')
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        if source[end] == '{': depth += 1
        elif source[end] == '}': depth -= 1
        end += 1
    source = source[:opening] + '{}' + source[end:]
source = source.replace('private func save()', 'func save()').replace('private func restore(', 'func restore(')
stubs = '''
class UserDefaults {
    static let standard = UserDefaults()
    var values: [String: Any] = [:]
    func integer(forKey key: String) -> Int { values[key] as? Int ?? 0 }
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
}

enum UIApplication {
    static let didEnterBackgroundNotification = Notification.Name("background")
    static let willEnterForegroundNotification = Notification.Name("foreground")
    static let willTerminateNotification = Notification.Name("terminate")
}
class AppSettings {
    var sessionsUntilLongBreak = 2
    var longBreakEnabled = false
    var longBreakTime = 3
    var isMuted = true
}
class StatsManager {
    var total = 0
    var sessions = 0
    func addStudyTime(seconds: Int) { total += seconds; sessions += 1 }
}
class FocusSoundManager {
    var currentSound: String? = nil
    func pause() {}
    func play() {}
    func stop() {}
}
class TimerStateManager {
    static let shared = TimerStateManager()
    typealias State = (timerRunning: Bool, isStudy: Bool, timerStartTime: Date?, timerEndTime: Date?, consecutiveSessions: Int, isLongBreak: Bool, studyTime: Int, restTime: Int)
    var state: State?
    func saveState(timerRunning: Bool, isStudy: Bool, timerStartTime: Date?, timerEndTime: Date?, consecutiveSessions: Int, isLongBreak: Bool, studyTime: Int, restTime: Int) {
        state = (timerRunning, isStudy, timerStartTime, timerEndTime, consecutiveSessions, isLongBreak, studyTime, restTime)
    }
    func loadState() -> State? { state }
    func clearState() { state = nil }
}
class LiveActivityManager {
    static let shared = LiveActivityManager()
    func startActivity(startTime: Date, endTime: Date, isStudy: Bool, sessionNumber: Int, totalSessions: Int) {}
    func updateActivity(startTime: Date, endTime: Date, isStudy: Bool, isPaused: Bool, sessionNumber: Int, totalSessions: Int) {}
    func endActivity() {}
}
'''
tests = '''
let settings = AppSettings()
let stats = StatsManager()
let session = PomodoroSession(settings: settings, stats: stats, soundManager: FocusSoundManager(), automaticallyUpdates: false)
session.studyTime = 1
session.restTime = 1
let start = Date(timeIntervalSince1970: 1_900_000_000)
session.toggleTimer(at: start)
precondition(session.hasSession && session.timerRunning && session.secondsLeft == 60)
session.tick(at: start.addingTimeInterval(15))
precondition(session.secondsLeft == 45)
// Navigation has no ownership of this object; subscribers can be discarded/recreated.
let pickerSession = session
pickerSession.tick(at: start.addingTimeInterval(30))
precondition(session.secondsLeft == 30 && session.timerRunning)
session.toggleTimer(at: start.addingTimeInterval(30))
session.tick(at: start.addingTimeInterval(90))
precondition(!session.timerRunning && session.hasSession && session.secondsLeft == 30)
session.toggleTimer(at: start.addingTimeInterval(90))
session.tick(at: start.addingTimeInterval(120))
precondition(!session.isStudy && session.secondsLeft == 60 && stats.total == 60 && stats.sessions == 1)
session.tick(at: start.addingTimeInterval(185))
precondition(session.isStudy && session.secondsLeft == 55)
session.tick(at: start.addingTimeInterval(185))
precondition(stats.total == 60 && stats.sessions == 1, "Repeated ticks must not double count")
session.resetTimer()
precondition(!session.hasSession && !session.timerRunning && session.isStudy && session.secondsLeft == 60)
settings.longBreakEnabled = true
session.toggleTimer(at: start)
session.tick(at: start.addingTimeInterval(180))
precondition(session.isLongBreak && !session.isStudy && session.secondsLeft == 180)
precondition(stats.total == 180 && stats.sessions == 3, "Catch-up accounts for each study session once")
session.tick(at: start.addingTimeInterval(365))
precondition(session.isStudy && session.secondsLeft == 55)
session.adjustTimerDuration(bySeconds: 30, at: start.addingTimeInterval(365))
precondition(session.secondsLeft == 85 && session.timerRunning)
precondition(session.studyTime == 1 && session.totalSeconds == 90, "Adjust current phase in seconds, preserving picker duration")
session.adjustTimerDuration(bySeconds: -10, at: start.addingTimeInterval(365))
precondition(session.secondsLeft == 75 && session.totalSeconds == 80)
session.adjustTimerDuration(bySeconds: -100, at: start.addingTimeInterval(365))
precondition(session.secondsLeft == 1 && session.totalSeconds == 6, "Subtraction stops at one second")
session.tick(at: start.addingTimeInterval(366))
precondition(!session.isStudy && session.secondsLeft == 60 && session.phaseDurationAdjustment == 0)
session.resetTimer()
precondition(session.consecutiveSessions == 0 && !session.hasSession)
// Restore a running session from a checkpoint without double-counting elapsed time.
let restoreStats = StatsManager()
let original = PomodoroSession(settings: settings, stats: restoreStats, soundManager: FocusSoundManager(), automaticallyUpdates: false)
original.studyTime = 1
original.restTime = 1
original.toggleTimer(at: start)
original.tick(at: start.addingTimeInterval(20))
original.adjustTimerDuration(bySeconds: 30, at: start.addingTimeInterval(20))
original.save()
let restored = PomodoroSession(settings: settings, stats: restoreStats, soundManager: FocusSoundManager(), automaticallyUpdates: false)
restored.restore(at: start.addingTimeInterval(30))
precondition(restored.timerRunning && restored.secondsLeft == 60 && restored.totalSeconds == 90)
restored.tick(at: start.addingTimeInterval(90))
precondition(restoreStats.total == 90 && restoreStats.sessions == 1)
restored.resetTimer()
// The previous app version has no remaining-time checkpoint; still recover it.
UserDefaults.standard.values = [:]
TimerStateManager.shared.saveState(timerRunning: true, isStudy: true, timerStartTime: start,
    timerEndTime: start.addingTimeInterval(60), consecutiveSessions: 0, isLongBreak: false, studyTime: 1, restTime: 1)
let legacy = PomodoroSession(settings: settings, stats: restoreStats, soundManager: FocusSoundManager(), automaticallyUpdates: false)
legacy.studyTime = 1
legacy.restTime = 1
legacy.restore(at: start.addingTimeInterval(30))
precondition(legacy.timerRunning && legacy.secondsLeft == 30)
legacy.resetTimer()
print("Passed persistence restoration plus shared-session navigation, pause/resume, reset, phase catch-up, long-break and accounting checks")
'''
with tempfile.TemporaryDirectory(prefix='odoro-session-tests-') as directory:
    path = Path(directory)
    (path / 'main.swift').write_text(source + stubs + tests)
    subprocess.run(['swiftc', '-module-cache-path', str(path / 'cache'), str(path / 'main.swift'), '-o', str(path / 'tests')], check=True)
    subprocess.run([str(path / 'tests')], check=True)
