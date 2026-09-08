import Foundation
internal import Combine
import AVFoundation
import AudioToolbox
import UserNotifications
import UIKit

// Owns the session for the lifetime of the app, independently of the visible screen.
final class PomodoroSession: ObservableObject {
    @Published var studyTime: Int {
        didSet { if !hasSession && isStudy { secondsLeft = studyTime * 60 } }
    }
    @Published var restTime: Int
    @Published private(set) var isStudy = true
    @Published private(set) var secondsLeft: Int
    @Published private(set) var timerRunning = false
    @Published private(set) var hasSession = false
    @Published private(set) var consecutiveSessions = 0
    @Published private(set) var isLongBreak = false
    private(set) var timerStartTime: Date?
    private(set) var timerEndTime: Date?
    @Published private(set) var phaseDurationAdjustment = 0
    private var studySecondsThisSession = 0
    private var subscriptions = Set<AnyCancellable>()
    private var audioPlayer: AVAudioPlayer?
    private let settings: AppSettings
    private let stats: StatsManager
    private let soundManager: FocusSoundManager
    private let liveActivityManager = LiveActivityManager.shared

    var phaseName: String { isStudy ? "Lock In" : (isLongBreak ? "Long Chill" : "Chill") }
    var status: String { "\(phaseName) \(timerRunning ? "in session" : "paused")" }
    var totalSeconds: Int { max(1, (isStudy ? studyTime : (isLongBreak ? settings.longBreakTime : restTime)) * 60 + phaseDurationAdjustment) }

    init(settings: AppSettings, stats: StatsManager, soundManager: FocusSoundManager,
         automaticallyUpdates: Bool = true) {
        self.settings = settings
        self.stats = stats
        self.soundManager = soundManager
        let savedStudy = UserDefaults.standard.integer(forKey: "savedStudyTime")
        let savedRest = UserDefaults.standard.integer(forKey: "savedRestTime")
        studyTime = savedStudy > 0 ? savedStudy : 25
        restTime = savedRest > 0 ? savedRest : 5
        secondsLeft = (savedStudy > 0 ? savedStudy : 25) * 60
        if automaticallyUpdates {
            restore()
            Timer.publish(every: 1, on: .main, in: .common).autoconnect()
                .sink { [weak self] date in self?.tick(at: date) }
                .store(in: &subscriptions)
            NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                .sink { [weak self] _ in self?.save() }
                .store(in: &subscriptions)
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    self?.tick()
                    self?.refreshLiveActivity()
                }
                .store(in: &subscriptions)
            NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
                .sink { [weak self] _ in self?.save() }
                .store(in: &subscriptions)
        }
    }

    func toggleTimer(at now: Date = Date()) {
        if timerRunning {
            tick(at: now)
            timerRunning = false
            cancelScheduledNotifications()
            soundManager.pause()
            liveActivityManager.updateActivity(startTime: timerStartTime ?? now,
                                               endTime: now.addingTimeInterval(TimeInterval(secondsLeft)),
                                               isStudy: isStudy, isPaused: true,
                                               sessionNumber: consecutiveSessions + 1,
                                               totalSessions: settings.sessionsUntilLongBreak)
            timerStartTime = nil
            timerEndTime = nil
        } else {
            hasSession = true
            timerRunning = true
            timerStartTime = now
            timerEndTime = now.addingTimeInterval(TimeInterval(secondsLeft))
            if isStudy && soundManager.currentSound != nil { soundManager.play() }
            liveActivityManager.startActivity(startTime: now, endTime: timerEndTime!, isStudy: isStudy,
                                              sessionNumber: consecutiveSessions + 1,
                                              totalSessions: settings.sessionsUntilLongBreak)
            scheduleTimerEndNotification(at: now)
        }
        save()
    }

    func tick(at now: Date = Date()) {
        guard timerRunning, let initialEnd = timerEndTime else { return }
        var end = initialEnd
        var phases = 0
        // Anchor every phase to its previous deadline, including time spent offscreen.
        while end <= now && phases < 500 {
            if isStudy { studySecondsThisSession += secondsLeft }
            advancePhase(at: end)
            phases += 1
            end = timerEndTime!
        }
        guard phases < 500 else { resetTimer(); return }
        let remaining = max(0, Int(ceil(end.timeIntervalSince(now))))
        if isStudy { studySecondsThisSession += max(0, secondsLeft - remaining) }
        secondsLeft = remaining
        if phases > 0 {
            if now.timeIntervalSince(initialEnd) < 2 && !settings.isMuted { playDingSound() }
            if isStudy && soundManager.currentSound != nil { soundManager.play() }
            else { soundManager.pause() }
            scheduleTimerEndNotification(at: now)
            refreshLiveActivity()
            save()
        }
    }

    private func advancePhase(at boundary: Date) {
        if isStudy {
            stats.addStudyTime(seconds: studySecondsThisSession)
            studySecondsThisSession = 0
            consecutiveSessions += 1
            isLongBreak = settings.longBreakEnabled && consecutiveSessions >= settings.sessionsUntilLongBreak
            if isLongBreak { consecutiveSessions = 0 }
            isStudy = false
        } else {
            isStudy = true
            isLongBreak = false
        }
        phaseDurationAdjustment = 0
        secondsLeft = totalSeconds
        timerStartTime = boundary
        timerEndTime = boundary.addingTimeInterval(TimeInterval(secondsLeft))
    }

    func adjustTimerDuration(bySeconds seconds: Int, at now: Date = Date()) {
        tick(at: now)
        let adjustedRemaining = max(1, secondsLeft + seconds)
        phaseDurationAdjustment += adjustedRemaining - secondsLeft
        secondsLeft = adjustedRemaining
        if timerRunning {
            timerEndTime = now.addingTimeInterval(TimeInterval(secondsLeft))
            scheduleTimerEndNotification(at: now)
            refreshLiveActivity()
        }
        save()
    }

    func resetTimer() {
        timerRunning = false
        hasSession = false
        isStudy = true
        isLongBreak = false
        consecutiveSessions = 0
        secondsLeft = studyTime * 60
        timerStartTime = nil
        timerEndTime = nil
        studySecondsThisSession = 0
        phaseDurationAdjustment = 0
        cancelScheduledNotifications()
        soundManager.stop()
        liveActivityManager.endActivity()
        TimerStateManager.shared.clearState()
        UserDefaults.standard.removeObject(forKey: "pomodoroStudySeconds")
        UserDefaults.standard.removeObject(forKey: "pomodoroRemainingSeconds")
        UserDefaults.standard.removeObject(forKey: "pomodoroPhaseAdjustment")
    }

    private func save() {
        if timerRunning {
            TimerStateManager.shared.saveState(timerRunning: true, isStudy: isStudy,
                                              timerStartTime: timerStartTime, timerEndTime: timerEndTime,
                                              consecutiveSessions: consecutiveSessions, isLongBreak: isLongBreak,
                                              studyTime: studyTime, restTime: restTime)
            UserDefaults.standard.set(studySecondsThisSession, forKey: "pomodoroStudySeconds")
            UserDefaults.standard.set(secondsLeft, forKey: "pomodoroRemainingSeconds")
            UserDefaults.standard.set(phaseDurationAdjustment, forKey: "pomodoroPhaseAdjustment")
        } else {
            TimerStateManager.shared.clearState()
        }
        UserDefaults.standard.set(studyTime, forKey: "savedStudyTime")
        UserDefaults.standard.set(restTime, forKey: "savedRestTime")
    }

    private func restore(at now: Date = Date()) {
        guard let state = TimerStateManager.shared.loadState(), let end = state.timerEndTime else { return }
        studyTime = state.studyTime
        restTime = state.restTime
        phaseDurationAdjustment = UserDefaults.standard.integer(forKey: "pomodoroPhaseAdjustment")
        isStudy = state.isStudy
        isLongBreak = state.isLongBreak
        consecutiveSessions = state.consecutiveSessions
        timerStartTime = state.timerStartTime
        timerEndTime = end
        // Resume from a saved remaining-time checkpoint to avoid double-counting study time.
        if let savedRemaining = UserDefaults.standard.object(forKey: "pomodoroRemainingSeconds") as? Int {
            secondsLeft = savedRemaining
            studySecondsThisSession = UserDefaults.standard.integer(forKey: "pomodoroStudySeconds")
        } else {
            // Compatibility with sessions saved before shared session ownership.
            secondsLeft = max(0, Int(ceil(end.timeIntervalSince(state.timerStartTime ?? now))))
            studySecondsThisSession = 0
        }
        hasSession = true
        timerRunning = true
        tick(at: now)
        guard timerRunning, let start = timerStartTime, let currentEnd = timerEndTime else { return }
        liveActivityManager.startActivity(startTime: start, endTime: currentEnd, isStudy: isStudy,
                                          sessionNumber: consecutiveSessions + 1,
                                          totalSessions: settings.sessionsUntilLongBreak)
        scheduleTimerEndNotification(at: now)
        save()
    }

    private func refreshLiveActivity() {
        guard timerRunning, let start = timerStartTime, let end = timerEndTime else { return }
        liveActivityManager.updateActivity(startTime: start, endTime: end, isStudy: isStudy, isPaused: false,
                                           sessionNumber: consecutiveSessions + 1,
                                           totalSessions: settings.sessionsUntilLongBreak)
    }

    private func scheduleTimerEndNotification(at now: Date = Date()) {
        cancelScheduledNotifications()
        guard settings.timerNotificationsEnabled, let end = timerEndTime, end > now else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(phaseName) Time Complete!"
        content.body = isStudy ? "Time for a break!" : "Time to study!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSince(now), repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "timer_end", content: content, trigger: trigger)) { _ in }
    }

    private func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_end", "timer_completed"])
    }

    private func playDingSound() {
        if let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.play()
                return
            } catch { }
        }
        AudioServicesPlaySystemSound(1007)
    }
}
