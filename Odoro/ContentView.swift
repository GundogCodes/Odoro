//
//  ContentView.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI
internal import Combine
import AVFoundation
import AudioToolbox
import UserNotifications
import Photos
import CoreMotion
import ActivityKit

// MARK: - Motion Manager for Gyroscope
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0  // Forward/back tilt
    @Published var roll: Double = 0   // Left/right tilt
    @Published var isActive = false
    
    init() {
        // Don't start automatically - wait for explicit start
    }
    
    func startMotionUpdates() {
        guard !isActive, motionManager.isDeviceMotionAvailable else { return }
        
        isActive = true
        motionManager.deviceMotionUpdateInterval = 1/30  // Reduced from 60fps to 30fps
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            self?.pitch = motion.attitude.pitch
            self?.roll = motion.attitude.roll
        }
    }
    
    func stopMotionUpdates() {
        guard isActive else { return }
        isActive = false
        motionManager.stopDeviceMotionUpdates()
        pitch = 0
        roll = 0
    }
    
    deinit {
        stopMotionUpdates()
    }
}

// MARK: - Fluid Wave Shape
struct FluidShape: Shape {
    var progress: CGFloat
    var waveOffset: CGFloat
    var waveHeight: CGFloat
    var tiltOffset: CGFloat
    
    var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(waveOffset, AnimatablePair(waveHeight, tiltOffset)) }
        set {
            waveOffset = newValue.first
            waveHeight = newValue.second.first
            tiltOffset = newValue.second.second
        }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let fillWidth = rect.width * progress
        let midY = rect.height / 2
        
        // Start at bottom left
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        // Line to top left
        path.addLine(to: CGPoint(x: 0, y: 0))
        
        // Create smooth wavy right edge using more points
        let steps = 50
        let stepHeight = rect.height / CGFloat(steps)
        
        for i in 0...steps {
            let y = CGFloat(i) * stepHeight
            let normalizedY = y / rect.height
            
            // Tilt effect - tilts the whole edge based on device roll
            let tiltEffect = tiltOffset * (normalizedY - 0.5) * 40
            
            // Multiple wave frequencies for more organic look
            let wave1 = sin(normalizedY * .pi * 2 + waveOffset) * waveHeight
            let wave2 = sin(normalizedY * .pi * 4 + waveOffset * 1.5) * (waveHeight * 0.3)
            let wave3 = sin(normalizedY * .pi * 6 + waveOffset * 0.7) * (waveHeight * 0.15)
            
            let totalWave = wave1 + wave2 + wave3
            let x = fillWidth + totalWave + tiltEffect
            
            if i == 0 {
                path.addLine(to: CGPoint(x: max(0, x), y: y))
            } else {
                path.addLine(to: CGPoint(x: max(0, x), y: y))
            }
        }
        
        // Close the path
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Fluid Fill View
struct FluidFillView: View {
    let progress: CGFloat
    let gradient: LinearGradient
    @ObservedObject var motionManager: MotionManager
    let isAnimating: Bool  // New parameter to control animation
    
    @State private var staticTime: Double = 0
    
    var body: some View {
        if isAnimating {
            // Animated version - only when timer is running
            TimelineView(.animation(minimumInterval: 1/30)) { timeline in  // Reduced to 30fps
                let time = timeline.date.timeIntervalSinceReferenceDate
                
                FluidShape(
                    progress: progress,
                    waveOffset: CGFloat(time * 1.5),
                    waveHeight: 12 + CGFloat(abs(motionManager.roll)) * 15,
                    tiltOffset: CGFloat(motionManager.roll)
                )
                .fill(gradient)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 0)
            }
            .ignoresSafeArea()
        } else {
            // Static version - when paused
            FluidShape(
                progress: progress,
                waveOffset: CGFloat(staticTime * 1.5),
                waveHeight: 12,
                tiltOffset: 0
            )
            .fill(gradient)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 0)
            .ignoresSafeArea()
            .onAppear {
                staticTime = Date().timeIntervalSinceReferenceDate
            }
        }
    }
}

// MARK: - Study Tips
struct StudyTips {
    static let tips: [String] = [
        "🧠 The Pomodoro Technique was invented by Francesco Cirillo in the late 1980s, named after his tomato-shaped kitchen timer.",
        "💡 Taking regular breaks actually improves focus. Your brain needs downtime to consolidate information.",
        "🎯 Work on your hardest tasks during your peak energy hours - usually 2-4 hours after waking up.",
        "📱 Put your phone in another room while studying. Even having it visible reduces cognitive capacity.",
        "💧 Stay hydrated! Dehydration can reduce concentration by up to 25%.",
        "🚶 Use breaks to move around. A short walk increases blood flow to the brain and boosts creativity.",
        "😴 Sleep is when your brain consolidates memories. Aim for 7-9 hours for optimal learning.",
        "✍️ Writing notes by hand improves retention compared to typing.",
        "🎵 If you listen to music while studying, choose instrumental tracks without lyrics.",
        "🍅 After 4 pomodoros, take a longer break (15-30 min) to recharge fully.",
        "📚 Spaced repetition is more effective than cramming. Review material over increasing intervals.",
        "🧘 Practice the 4-7-8 breathing technique during breaks: inhale 4s, hold 7s, exhale 8s.",
        "🌿 Plants in your study space can improve air quality and reduce stress.",
        "📝 Start each session by writing down your specific goal. Clarity boosts productivity.",
        "🔄 Switch between different subjects to prevent mental fatigue.",
        "☀️ Natural light improves alertness. Study near a window when possible.",
        "🎯 Break large tasks into smaller chunks. Small wins build momentum.",
        "🚫 Multitasking is a myth. Focus on one thing at a time for better results.",
        "⏰ Your willpower is highest in the morning. Schedule important work early.",
        "🧩 Connect new information to things you already know. It strengthens memory formation."
    ]
    
    static func randomTip() -> String {
        tips.randomElement() ?? tips[0]
    }
}

// MARK: - Session Statistics Manager
class StatsManager: ObservableObject {
    @Published var todayStudySeconds: Int {
        didSet { save() }
    }
    @Published var weekStudySeconds: Int {
        didSet { save() }
    }
    @Published var allTimeStudySeconds: Int {
        didSet { save() }
    }
    @Published var sessionsCompleted: Int {
        didSet { save() }
    }
    @Published var currentStreak: Int {
        didSet { save() }
    }
    @Published var lastStudyDate: Date? {
        didSet { save() }
    }
    @Published var weekStartDate: Date? {
        didSet { save() }
    }
    
    private let defaults = UserDefaults.standard
    
    init() {
        self.todayStudySeconds = defaults.integer(forKey: "todayStudySeconds")
        self.weekStudySeconds = defaults.integer(forKey: "weekStudySeconds")
        self.allTimeStudySeconds = defaults.integer(forKey: "allTimeStudySeconds")
        self.sessionsCompleted = defaults.integer(forKey: "sessionsCompleted")
        self.currentStreak = defaults.integer(forKey: "currentStreak")
        if let date = defaults.object(forKey: "lastStudyDate") as? Date {
            self.lastStudyDate = date
        } else {
            self.lastStudyDate = nil
        }
        if let date = defaults.object(forKey: "weekStartDate") as? Date {
            self.weekStartDate = date
        } else {
            self.weekStartDate = nil
        }
        checkAndResetIfNeeded()
    }
    
    func save() {
        defaults.set(todayStudySeconds, forKey: "todayStudySeconds")
        defaults.set(weekStudySeconds, forKey: "weekStudySeconds")
        defaults.set(allTimeStudySeconds, forKey: "allTimeStudySeconds")
        defaults.set(sessionsCompleted, forKey: "sessionsCompleted")
        defaults.set(currentStreak, forKey: "currentStreak")
        if let date = lastStudyDate {
            defaults.set(date, forKey: "lastStudyDate")
        }
        if let date = weekStartDate {
            defaults.set(date, forKey: "weekStartDate")
        }
    }
    
    func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // Reset daily stats if it's a new day
        if let lastDate = lastStudyDate {
            if !calendar.isDateInToday(lastDate) {
                todayStudySeconds = 0
                sessionsCompleted = 0
                
                // Check streak
                if calendar.isDateInYesterday(lastDate) {
                    // Streak continues
                } else {
                    // Streak broken
                    currentStreak = 0
                }
            }
            
            // Reset weekly stats if it's a new week
            if !calendar.isDate(lastDate, equalTo: now, toGranularity: .weekOfYear) {
                weekStudySeconds = 0
                weekStartDate = calendar.startOfDay(for: now)
            }
        }
        
        // Set week start date if not set
        if weekStartDate == nil {
            weekStartDate = calendar.startOfDay(for: now)
        }
    }
    
    func addStudyTime(seconds: Int) {
        let calendar = Calendar.current
        let now = Date()
        
        // Update streak if this is first study of the day
        if let lastDate = lastStudyDate {
            if !calendar.isDateInToday(lastDate) {
                currentStreak += 1
            }
        } else {
            currentStreak = 1
        }
        
        todayStudySeconds += seconds
        weekStudySeconds += seconds
        allTimeStudySeconds += seconds
        sessionsCompleted += 1
        lastStudyDate = now
    }
    
    var todayFormatted: String {
        formatTime(seconds: todayStudySeconds)
    }
    
    var weekFormatted: String {
        formatTime(seconds: weekStudySeconds)
    }
    
    var allTimeFormatted: String {
        formatTimeLong(seconds: allTimeStudySeconds)
    }
    
    var weeklyAverageFormatted: String {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate days elapsed in current week
        var daysElapsed = 1
        if let startDate = weekStartDate {
            let components = calendar.dateComponents([.day], from: startDate, to: now)
            daysElapsed = max(1, (components.day ?? 0) + 1)
        }
        
        let averageSeconds = weekStudySeconds / daysElapsed
        return formatTime(seconds: averageSeconds)
    }
    
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatTimeLong(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours >= 100 {
            return "\(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Focus Sound Manager
class FocusSoundManager: ObservableObject {
    @Published var currentSound: FocusSound? {
        didSet {
            UserDefaults.standard.set(currentSound?.rawValue ?? "", forKey: "focusSound")
        }
    }
    @Published var volume: Float = 0.5 {
        didSet {
            audioPlayer?.volume = volume
            UserDefaults.standard.set(volume, forKey: "focusSoundVolume")
        }
    }
    @Published var isPlaying = false
    
    private var audioPlayer: AVAudioPlayer?
    
    enum FocusSound: String, CaseIterable {
        case rain = "rain"
        case lofi = "lofi"
        case whiteNoise = "whitenoise"
        case coffeeShop = "coffeeshop"
        case forest = "forest"
        case ocean = "ocean"
        
        var displayName: String {
            switch self {
            case .rain: return "🌧️ Rain"
            case .lofi: return "🎵 Lo-Fi"
            case .whiteNoise: return "📻 White Noise"
            case .coffeeShop: return "☕ Coffee Shop"
            case .forest: return "🌲 Forest"
            case .ocean: return "🌊 Ocean"
            }
        }
        
        var fileName: String {
            rawValue
        }
    }
    
    init() {
        if let savedSound = UserDefaults.standard.string(forKey: "focusSound"),
           !savedSound.isEmpty,
           let sound = FocusSound(rawValue: savedSound) {
            self.currentSound = sound
        }
        self.volume = UserDefaults.standard.float(forKey: "focusSoundVolume")
        if volume == 0 { volume = 0.5 }
        
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func play() {
        guard let sound = currentSound else { return }
        
        let extensions = ["mp3", "m4a", "wav", "aac"]
        var url: URL?
        
        for ext in extensions {
            if let foundURL = Bundle.main.url(forResource: sound.fileName, withExtension: ext) {
                url = foundURL
                break
            }
        }
        
        guard let audioURL = url else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: audioURL)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Error playing sound: \(error)")
        }
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
    
    func setSound(_ sound: FocusSound?) {
        stop()
        currentSound = sound
        if sound != nil {
            play()
        }
    }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    static let defaultStudyColor: Color = .purple
    static let defaultRestColor: Color = .red
    static let defaultStudyBackgroundColor: Color = Color.green.opacity(0.3)
    static let defaultRestBackgroundColor: Color = Color.orange.opacity(0.7)
    
    @Published var studyColor: Color {
        didSet { saveColor(studyColor, key: "studyColor") }
    }
    @Published var restColor: Color {
        didSet { saveColor(restColor, key: "restColor") }
    }
    @Published var studyBackgroundColor: Color {
        didSet { saveColor(studyBackgroundColor, key: "studyBackgroundColor") }
    }
    @Published var restBackgroundColor: Color {
        didSet { saveColor(restBackgroundColor, key: "restBackgroundColor") }
    }
    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "isMuted") }
    }
    @Published var longBreakTime: Int {
        didSet { UserDefaults.standard.set(longBreakTime, forKey: "longBreakTime") }
    }
    @Published var sessionsUntilLongBreak: Int {
        didSet { UserDefaults.standard.set(sessionsUntilLongBreak, forKey: "sessionsUntilLongBreak") }
    }
    @Published var longBreakEnabled: Bool {
        didSet { UserDefaults.standard.set(longBreakEnabled, forKey: "longBreakEnabled") }
    }
    
    init() {
        self.studyColor = Self.loadColor(key: "studyColor") ?? Self.defaultStudyColor
        self.restColor = Self.loadColor(key: "restColor") ?? Self.defaultRestColor
        self.studyBackgroundColor = Self.loadColor(key: "studyBackgroundColor") ?? Self.defaultStudyBackgroundColor
        self.restBackgroundColor = Self.loadColor(key: "restBackgroundColor") ?? Self.defaultRestBackgroundColor
        self.isMuted = UserDefaults.standard.bool(forKey: "isMuted")
        
        let savedLongBreak = UserDefaults.standard.integer(forKey: "longBreakTime")
        self.longBreakTime = savedLongBreak > 0 ? savedLongBreak : 15
        
        let savedSessions = UserDefaults.standard.integer(forKey: "sessionsUntilLongBreak")
        self.sessionsUntilLongBreak = savedSessions > 0 ? savedSessions : 4
        
        self.longBreakEnabled = UserDefaults.standard.bool(forKey: "longBreakEnabled")
    }
    
    func resetToDefaults() {
        studyColor = Self.defaultStudyColor
        restColor = Self.defaultRestColor
        studyBackgroundColor = Self.defaultStudyBackgroundColor
        restBackgroundColor = Self.defaultRestBackgroundColor
    }
    
    private func saveColor(_ color: Color, key: String) {
        let uiColor = UIColor(color)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: uiColor, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    private static func loadColor(key: String) -> Color? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let uiColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) else {
            return nil
        }
        return Color(uiColor)
    }
}

// MARK: - Live Activity Manager
// MARK: - Timer State Persistence
class TimerStateManager {
    static let shared = TimerStateManager()
    
    private let defaults = UserDefaults.standard
    private let timerRunningKey = "timerRunning"
    private let isStudyKey = "isStudy"
    private let timerEndTimeKey = "timerEndTime"
    private let timerStartTimeKey = "timerStartTime"
    private let consecutiveSessionsKey = "consecutiveSessions"
    private let isLongBreakKey = "isLongBreak"
    private let studyTimeKey = "savedStudyTime"
    private let restTimeKey = "savedRestTime"
    
    func saveState(timerRunning: Bool, isStudy: Bool, timerStartTime: Date?, timerEndTime: Date?, consecutiveSessions: Int, isLongBreak: Bool, studyTime: Int, restTime: Int) {
        defaults.set(timerRunning, forKey: timerRunningKey)
        defaults.set(isStudy, forKey: isStudyKey)
        defaults.set(timerStartTime, forKey: timerStartTimeKey)
        defaults.set(timerEndTime, forKey: timerEndTimeKey)
        defaults.set(consecutiveSessions, forKey: consecutiveSessionsKey)
        defaults.set(isLongBreak, forKey: isLongBreakKey)
        defaults.set(studyTime, forKey: studyTimeKey)
        defaults.set(restTime, forKey: restTimeKey)
        print("💾 Timer state saved: running=\(timerRunning), isStudy=\(isStudy), endTime=\(String(describing: timerEndTime))")
    }
    
    func loadState() -> (timerRunning: Bool, isStudy: Bool, timerStartTime: Date?, timerEndTime: Date?, consecutiveSessions: Int, isLongBreak: Bool, studyTime: Int, restTime: Int)? {
        let timerRunning = defaults.bool(forKey: timerRunningKey)
        guard timerRunning else { return nil }
        
        let isStudy = defaults.bool(forKey: isStudyKey)
        let timerStartTime = defaults.object(forKey: timerStartTimeKey) as? Date
        let timerEndTime = defaults.object(forKey: timerEndTimeKey) as? Date
        let consecutiveSessions = defaults.integer(forKey: consecutiveSessionsKey)
        let isLongBreak = defaults.bool(forKey: isLongBreakKey)
        let studyTime = defaults.integer(forKey: studyTimeKey)
        let restTime = defaults.integer(forKey: restTimeKey)
        
        print("📂 Timer state loaded: running=\(timerRunning), isStudy=\(isStudy), endTime=\(String(describing: timerEndTime))")
        return (timerRunning, isStudy, timerStartTime, timerEndTime, consecutiveSessions, isLongBreak, studyTime, restTime)
    }
    
    func clearState() {
        defaults.removeObject(forKey: timerRunningKey)
        defaults.removeObject(forKey: isStudyKey)
        defaults.removeObject(forKey: timerStartTimeKey)
        defaults.removeObject(forKey: timerEndTimeKey)
        defaults.removeObject(forKey: consecutiveSessionsKey)
        defaults.removeObject(forKey: isLongBreakKey)
        defaults.removeObject(forKey: studyTimeKey)
        defaults.removeObject(forKey: restTimeKey)
        print("🗑️ Timer state cleared")
    }
}

class LiveActivityManager: ObservableObject {
    @Published var currentActivity: Activity<OdoroTimerAttributes>?
    
    static let shared = LiveActivityManager()
    
    func startActivity(startTime: Date, endTime: Date, isStudy: Bool, sessionNumber: Int, totalSessions: Int) {
        let authInfo = ActivityAuthorizationInfo()
        print("🔴 Live Activity Debug:")
        print("   - areActivitiesEnabled: \(authInfo.areActivitiesEnabled)")
        print("   - startTime: \(startTime)")
        print("   - endTime: \(endTime)")
        print("   - isStudy: \(isStudy)")
        
        guard authInfo.areActivitiesEnabled else {
            print("❌ Live Activities not enabled!")
            return
        }
        
        // End any existing activity first
        if let existing = currentActivity {
            Task {
                await existing.end(nil, dismissalPolicy: .immediate)
                await MainActor.run {
                    self.createNewActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, sessionNumber: sessionNumber, totalSessions: totalSessions)
                }
            }
        } else {
            createNewActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, sessionNumber: sessionNumber, totalSessions: totalSessions)
        }
    }
    
    private func createNewActivity(startTime: Date, endTime: Date, isStudy: Bool, sessionNumber: Int, totalSessions: Int) {
        let attributes = OdoroTimerAttributes(timerName: "Odoro")
        let contentState = OdoroTimerAttributes.ContentState(
            startTime: startTime,
            endTime: endTime,
            isStudy: isStudy,
            isPaused: false,
            sessionNumber: sessionNumber,
            totalSessions: totalSessions
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: endTime),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Started Live Activity: \(activity.id)")
        } catch {
            print("❌ Error starting Live Activity: \(error)")
        }
    }
    
    func updateActivity(startTime: Date, endTime: Date, isStudy: Bool, isPaused: Bool, sessionNumber: Int, totalSessions: Int) {
        guard let activity = currentActivity else {
            print("⚠️ No current activity to update")
            return
        }
        
        let contentState = OdoroTimerAttributes.ContentState(
            startTime: startTime,
            endTime: endTime,
            isStudy: isStudy,
            isPaused: isPaused,
            sessionNumber: sessionNumber,
            totalSessions: totalSessions
        )
        
        print("🔄 Updating Live Activity: isStudy=\(isStudy)")
        
        Task {
            await activity.update(
                ActivityContent(state: contentState, staleDate: isPaused ? nil : endTime.addingTimeInterval(60))
            )
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
    
    func cleanupOrphanedActivities() {
        Task {
            for activity in Activity<OdoroTimerAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        currentActivity = nil
    }
}

// MARK: - Camera Manager for Timelapse
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var previewImage: UIImage?
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var captureTimer: Timer?
    private var shouldCaptureFrame = false
    
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "videoOutputQueue")
    private let writerQueue = DispatchQueue(label: "writerQueue")
    
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var frameCount: Int64 = 0
    private var outputURL: URL?
    private var videoSize: CGSize?
    private var isWriterReady = false
    
    // Dynamic interval tracking
    private var recordingStartTime: Date?
    private var currentInterval: TimeInterval = 1.0  // Start at 1 fps (less aggressive)
    
    // Preview optimization - only update every N frames
    private var previewFrameCounter = 0
    private let previewUpdateInterval = 30  // Update preview every 30 frames (~2 per second at 15fps)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])  // Reuse context
    
    var onTimelapseComplete: ((URL?) -> Void)?
    
    override init() {
        super.init()
    }
    
    // Apple-style dynamic interval based on recording duration
    private func getInterval(forElapsedMinutes minutes: Double) -> TimeInterval {
        switch minutes {
        case 0..<10:
            return 1.0    // 1 fps (reduced from 2 fps for less heat)
        case 10..<20:
            return 2.0    // 1 frame every 2 seconds
        case 20..<40:
            return 4.0    // 1 frame every 4 seconds
        case 40..<80:
            return 6.0    // 1 frame every 6 seconds
        default:
            return 8.0    // 1 frame every 8 seconds for very long recordings
        }
    }
    
    private func updateCaptureInterval() {
        guard let startTime = recordingStartTime else { return }
        let elapsedMinutes = Date().timeIntervalSince(startTime) / 60.0
        let newInterval = getInterval(forElapsedMinutes: elapsedMinutes)
        
        if newInterval != currentInterval {
            currentInterval = newInterval
            // Restart timer with new interval
            captureTimer?.invalidate()
            captureTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
                self?.shouldCaptureFrame = true
            }
            print("📸 Timelapse interval changed to \(currentInterval)s at \(String(format: "%.1f", elapsedMinutes)) minutes")
        }
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            self?.setupCameraSession()
        }
    }
    
    private func setupCameraSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium  // Balanced resolution for quality/performance
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            return
        }
        
        // Optimize camera for lower power consumption
        try? frontCamera.lockForConfiguration()
        if frontCamera.isLowLightBoostSupported {
            frontCamera.automaticallyEnablesLowLightBoostWhenAvailable = false
        }
        // Reduce frame rate to 15 fps for less heat
        frontCamera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
        frontCamera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
        frontCamera.unlockForConfiguration()
        
        if captureSession?.canAddInput(input) == true {
            captureSession?.addInput(input)
        }
        
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput?.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        
        if let videoOutput = videoOutput, captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
            
            if let connection = videoOutput.connection(with: .video) {
                connection.videoRotationAngle = 90
                connection.isVideoMirrored = true
            }
        }
        
        captureSession?.startRunning()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = true
            self.frameCount = 0
            self.isWriterReady = false
            self.videoSize = nil
            self.recordingStartTime = Date()
            self.currentInterval = 1.0  // Start at 1 fps
            self.previewFrameCounter = 0
        }
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: currentInterval, repeats: true) { [weak self] _ in
            self?.shouldCaptureFrame = true
            self?.updateCaptureInterval()
        }
    }
    
    private func setupAssetWriter(size: CGSize) {
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("timelapse_\(Date().timeIntervalSince1970).mp4")
            try? FileManager.default.removeItem(at: url)
            self.outputURL = url
            self.videoSize = size
            
            guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
            
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 1000000,  // Reduced bitrate for less processing
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264MainAutoLevel  // Simpler profile
                ]
            ]
            
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = true
            
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: writerInput,
                sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferWidthKey as String: size.width,
                    kCVPixelBufferHeightKey as String: size.height
                ]
            )
            
            if writer.canAdd(writerInput) {
                writer.add(writerInput)
            }
            
            self.assetWriter = writer
            self.assetWriterInput = writerInput
            self.pixelBufferAdaptor = adaptor
            
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            
            self.isWriterReady = true
        }
    }
    
    private func appendFrame(pixelBuffer: CVPixelBuffer) {
        writerQueue.async { [weak self] in
            guard let self = self,
                  self.isWriterReady,
                  let writerInput = self.assetWriterInput,
                  let adaptor = self.pixelBufferAdaptor,
                  writerInput.isReadyForMoreMediaData else { return }
            
            let frameDuration = CMTime(value: 1, timescale: 30)
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(self.frameCount))
            
            if adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                self.frameCount += 1
            }
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        captureTimer?.invalidate()
        captureTimer = nil
        
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let writer = self.assetWriter,
                  let input = self.assetWriterInput,
                  self.frameCount > 0 else {
                DispatchQueue.main.async {
                    self.onTimelapseComplete?(nil)
                }
                return
            }
            
            input.markAsFinished()
            
            writer.finishWriting { [weak self] in
                guard let self = self else { return }
                
                if writer.status == .completed, let url = self.outputURL {
                    self.saveToPhotoLibrary(url: url)
                } else {
                    DispatchQueue.main.async {
                        self.onTimelapseComplete?(nil)
                    }
                }
                
                self.assetWriter = nil
                self.assetWriterInput = nil
                self.pixelBufferAdaptor = nil
                self.isWriterReady = false
            }
        }
    }
    
    private func saveToPhotoLibrary(url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized else {
                DispatchQueue.main.async { self.onTimelapseComplete?(nil) }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    self.onTimelapseComplete?(success ? url : nil)
                }
            }
        }
    }
    
    func cleanup() {
        captureTimer?.invalidate()
        captureTimer = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            self.previewImage = nil
            self.recordingStartTime = nil
            self.currentInterval = 1.0
            self.previewFrameCounter = 0
        }
        
        sessionQueue.sync { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.videoOutput = nil
        }
        
        writerQueue.async { [weak self] in
            self?.assetWriter?.cancelWriting()
            self?.assetWriter = nil
            self?.assetWriterInput = nil
            self?.pixelBufferAdaptor = nil
            self?.isWriterReady = false
        }
    }
    
    func pauseSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        print("📷 Camera session paused")
    }
    
    func resumeSession() {
        sessionQueue.async { [weak self] in
            if self?.captureSession?.isRunning == false {
                self?.captureSession?.startRunning()
            }
        }
        print("📷 Camera session resumed")
    }
    
    func stopAndSave(completion: (() -> Void)? = nil) {
        guard isRecording else {
            completion?()
            return
        }
        
        onTimelapseComplete = { [weak self] url in
            self?.cleanup()
            completion?()
        }
        stopRecording()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        autoreleasepool {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Only update preview every N frames to reduce CPU/GPU usage and memory
            previewFrameCounter += 1
            if previewFrameCounter >= previewUpdateInterval {
                previewFrameCounter = 0
                
                autoreleasepool {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                    if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
                        let image = UIImage(cgImage: cgImage)
                        DispatchQueue.main.async { [weak self] in
                            self?.previewImage = image
                        }
                    }
                }
            }
            
            if isRecording && shouldCaptureFrame {
                shouldCaptureFrame = false
                
                if !isWriterReady && videoSize == nil {
                    let width = CVPixelBufferGetWidth(pixelBuffer)
                    let height = CVPixelBufferGetHeight(pixelBuffer)
                    setupAssetWriter(size: CGSize(width: width, height: height))
                }
                
                if isWriterReady {
                    var copiedBuffer: CVPixelBuffer?
                    let width = CVPixelBufferGetWidth(pixelBuffer)
                    let height = CVPixelBufferGetHeight(pixelBuffer)
                    
                    CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                       CVPixelBufferGetPixelFormatType(pixelBuffer),
                                       nil, &copiedBuffer)
                    
                    if let copiedBuffer = copiedBuffer {
                        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
                        CVPixelBufferLockBaseAddress(copiedBuffer, [])
                        
                        let srcData = CVPixelBufferGetBaseAddress(pixelBuffer)
                        let destData = CVPixelBufferGetBaseAddress(copiedBuffer)
                        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
                        
                        if let srcData = srcData, let destData = destData {
                            memcpy(destData, srcData, bytesPerRow * height)
                        }
                        
                        CVPixelBufferUnlockBaseAddress(copiedBuffer, [])
                        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
                        
                        appendFrame(pixelBuffer: copiedBuffer)
                    }
                }
            }
        }
    }
}

// MARK: - Draggable Camera Preview
struct DraggableCameraPreview: View {
    @ObservedObject var cameraManager: CameraManager
    @Binding var isHidden: Bool
    @State private var position: CGPoint = CGPoint(x: 80, y: 150)
    @State private var dragOffset: CGSize = .zero
    @State private var recordingDuration: Int = 0
    @State private var recordingTimer: Timer?
    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    var rotationAngle: Double {
        if !isLandscape { return 0 }
        switch deviceOrientation {
        case .landscapeLeft: return -90
        case .landscapeRight: return 90
        default: return -90
        }
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 0) {
                ZStack {
                    if let image = cameraManager.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 170)
                            .rotationEffect(.degrees(rotationAngle))
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.black)
                            .frame(width: 130, height: 170)
                            .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)))
                    }
                    
                    VStack {
                        HStack {
                            ViewfinderCorner(rotation: 0)
                            Spacer()
                            ViewfinderCorner(rotation: 90)
                        }
                        Spacer()
                        HStack {
                            ViewfinderCorner(rotation: -90)
                            Spacer()
                            ViewfinderCorner(rotation: 180)
                        }
                    }
                    .padding(8)
                    .frame(width: 130, height: 170)
                    
                    if cameraManager.isRecording {
                        VStack {
                            HStack {
                                HStack(spacing: 4) {
                                    Circle().fill(.red).frame(width: 8, height: 8).shadow(color: .red, radius: 3)
                                    Text("REC").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.white)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.6)))
                                
                                Spacer()
                                
                                Text(formatDuration(recordingDuration))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(Capsule().fill(.black.opacity(0.6)))
                            }
                            .padding(6)
                            Spacer()
                        }
                        .frame(width: 130, height: 170)
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.3)) { isHidden = true }
                            } label: {
                                Image(systemName: "eye.slash.fill")
                                    .font(.system(size: 12)).foregroundColor(.white)
                                    .padding(6).background(Circle().fill(.black.opacity(0.5)))
                            }
                            .padding(6)
                        }
                    }
                    .frame(width: 130, height: 170)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(8)
            }
        }
        .frame(width: 146, height: 186)
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .gesture(
            DragGesture()
                .onChanged { value in dragOffset = value.translation }
                .onEnded { value in
                    position.x += value.translation.width
                    position.y += value.translation.height
                    dragOffset = .zero
                }
        )
        .onAppear {
            startRecordingTimer()
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            deviceOrientation = UIDevice.current.orientation
        }
        .onDisappear { recordingTimer?.invalidate() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isLandscape || newOrientation.isPortrait {
                deviceOrientation = newOrientation
            }
        }
        .onChange(of: cameraManager.isRecording) { _, isRecording in
            if isRecording {
                recordingDuration = 0
                startRecordingTimer()
            } else {
                recordingTimer?.invalidate()
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if cameraManager.isRecording { recordingDuration += 1 }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

struct ViewfinderCorner: View {
    let rotation: Double
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 12))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 12, y: 0))
        }
        .stroke(Color.white.opacity(0.8), lineWidth: 2)
        .frame(width: 12, height: 12)
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Glass Button Style
struct GlassButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .blue
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                    if isActive {
                        RoundedRectangle(cornerRadius: 14).fill(activeColor.opacity(0.3))
                    }
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.2)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Settings Panel
struct SettingsPanel: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var soundManager: FocusSoundManager
    @Binding var isPresented: Bool
    @State private var currentTip: String = StudyTips.randomTip()
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Text("Settings").font(.title2.bold()).foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4)) { isPresented = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
                
                Picker("", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Sounds").tag(1)
                    Text("Tips").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24).padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if selectedTab == 0 { generalSettings }
                        else if selectedTab == 1 { soundSettings }
                        else { tipsSection }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }
            }
            .frame(maxWidth: 380, maxHeight: 520)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 28).fill(Color.black.opacity(0.35))
                    RoundedRectangle(cornerRadius: 28)
                        .fill(LinearGradient(colors: [.purple.opacity(0.25), .blue.opacity(0.15)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        }
    }
    
    var generalSettings: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fill Colors").font(.headline).foregroundColor(.white)
                HStack {
                    Text("Lock In Fill").foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.studyColor, supportsOpacity: false).labelsHidden()
                }
                HStack {
                    Text("Chill Fill").foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.restColor, supportsOpacity: false).labelsHidden()
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Background Colors").font(.headline).foregroundColor(.white)
                HStack {
                    Text("Lock In Background").foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.studyBackgroundColor, supportsOpacity: true).labelsHidden()
                }
                HStack {
                    Text("Chill Background").foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.restBackgroundColor, supportsOpacity: true).labelsHidden()
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            Button {
                withAnimation { settings.resetToDefaults() }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Colors to Default")
                }
                .font(.subheadline.bold()).foregroundColor(.white)
                .frame(maxWidth: .infinity).padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.15)))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.longBreakEnabled) {
                    Text("Long Chill").font(.headline).foregroundColor(.white)
                }
                .tint(.orange)
                
                Text("Take an extended chill session after completing multiple lock in sessions.")
                    .font(.caption).foregroundColor(.white.opacity(0.6))
                
                if settings.longBreakEnabled {
                    HStack {
                        Text("After").foregroundColor(.white.opacity(0.8))
                        Picker("", selection: $settings.sessionsUntilLongBreak) {
                            ForEach(2...8, id: \.self) { Text("\($0) sessions").tag($0) }
                        }
                        .pickerStyle(.menu).tint(.white)
                    }
                    HStack {
                        Text("Duration").foregroundColor(.white.opacity(0.8))
                        Picker("", selection: $settings.longBreakTime) {
                            ForEach([10, 15, 20, 25, 30], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .pickerStyle(.menu).tint(.white)
                    }
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mute Sound").font(.headline).foregroundColor(.white)
                    Text("Silence the ding").font(.caption).foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Toggle("", isOn: $settings.isMuted).labelsHidden().tint(.orange)
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        }
    }
    
    var soundSettings: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus Sounds").font(.headline).foregroundColor(.white)
                Text("Plays during study, pauses on break").font(.caption).foregroundColor(.white.opacity(0.6))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FocusSoundManager.FocusSound.allCases, id: \.rawValue) { sound in
                        let isAvailable = soundFileExists(sound)
                        Button {
                            if soundManager.currentSound == sound { soundManager.setSound(nil) }
                            else { soundManager.setSound(sound) }
                        } label: {
                            HStack {
                                Text(sound.displayName).font(.subheadline.bold())
                                if !isAvailable {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundColor(.yellow)
                                }
                            }
                            .foregroundColor(isAvailable ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(soundManager.currentSound == sound ? .blue.opacity(0.5) : .white.opacity(0.15)))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(soundManager.currentSound == sound ? .blue : .clear, lineWidth: 2))
                        }
                        .disabled(!isAvailable)
                    }
                }
                
                Button {
                    soundManager.setSound(nil)
                } label: {
                    Text("🔇 None").font(.subheadline.bold()).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(soundManager.currentSound == nil ? .blue.opacity(0.5) : .white.opacity(0.15)))
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            if soundManager.currentSound != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume").font(.headline).foregroundColor(.white)
                    HStack {
                        Image(systemName: "speaker.fill").foregroundColor(.white.opacity(0.6))
                        Slider(value: $soundManager.volume, in: 0...1).tint(.blue)
                        Image(systemName: "speaker.wave.3.fill").foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            }
        }
    }
    
    var tipsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill").foregroundColor(.yellow)
                    Text("Study Tip").font(.headline).foregroundColor(.white)
                }
                Text(currentTip).font(.body).foregroundColor(.white.opacity(0.9)).fixedSize(horizontal: false, vertical: true)
                Button {
                    withAnimation { currentTip = StudyTips.randomTip() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("New Tip")
                    }
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.5)))
                }
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Facts").font(.headline).foregroundColor(.white)
                FactRow(icon: "brain.head.profile", text: "Your brain can only focus for 90-120 minutes at a time")
                FactRow(icon: "clock.fill", text: "The ideal study session is 25-50 minutes")
                FactRow(icon: "bed.double.fill", text: "Memory consolidation happens during sleep")
                FactRow(icon: "figure.walk", text: "Walking boosts creativity by up to 60%")
            }
            .padding(16).background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        }
    }
    
    func soundFileExists(_ sound: FocusSoundManager.FocusSound) -> Bool {
        let extensions = ["mp3", "m4a", "wav", "aac"]
        for ext in extensions {
            if Bundle.main.url(forResource: sound.fileName, withExtension: ext) != nil { return true }
        }
        return false
    }
}

struct FactRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).foregroundColor(.orange).frame(width: 24)
            Text(text).font(.caption).foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Logo Screen
struct LogoScreen: View {
    @Binding var isFinished: Bool
    @State private var jumpUp = false

    var body: some View {
        ZStack {
            AnimatedMeshBackground()
            
            VStack {
                HStack {
                    Image("logo2")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 90, maxWidth:120)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white, lineWidth: 6))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .offset(y: jumpUp ? -20 : 0)
                        .animation(.easeInOut(duration: 0.3), value: jumpUp)
                        .onAppear {
                            jumpUp = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { jumpUp = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                isFinished = false
                                let currentCount = UserDefaults.standard.integer(forKey: "logoViewCount")
                                UserDefaults.standard.set(currentCount + 1, forKey: "logoViewCount")
                            }
                        }

                    Image("odoro")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 250)
                        .padding(.leading)
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                }
                .padding(.top, 100)

                Text("Your study buddy")
                    .padding(.top, 100)
                    .font(.headline).bold()
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
            }
        }
    }
}

// MARK: - Animated Mesh Background
struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var wave1FromTop: Bool = false
    @State private var wave2FromTop: Bool = true
    @State private var wave3FromTop: Bool = false
    @State private var speedMultiplier1: Double = 1.0
    @State private var speedMultiplier2: Double = 1.0
    @State private var speedMultiplier3: Double = 1.0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1/20)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            GeometryReader { geo in
                ZStack {
                    if colorScheme == .dark {
                        Color(red: 0.0, green: 0.45, blue: 0.4)
                        HorizontalFluidWave(time: time, fromTop: wave1FromTop, baseHeight: 0.65, amplitude: 50, frequency: 1.0, speed: 0.6 * speedMultiplier1, color: Color(red: 0.0, green: 0.7, blue: 0.5))
                        HorizontalFluidWave(time: time, fromTop: wave2FromTop, baseHeight: 0.55, amplitude: 45, frequency: 1.2, speed: 0.8 * speedMultiplier2, color: Color(red: 0.1, green: 0.85, blue: 0.65))
                        HorizontalFluidWave(time: time, fromTop: wave3FromTop, baseHeight: 0.4, amplitude: 40, frequency: 1.4, speed: 1.0 * speedMultiplier3, color: Color(red: 0.2, green: 0.95, blue: 0.6))
                    } else {
                        Color(red: 1.0, green: 0.75, blue: 0.3)
                        HorizontalFluidWave(time: time, fromTop: wave1FromTop, baseHeight: 0.7, amplitude: 55, frequency: 0.9, speed: 0.55 * speedMultiplier1, color: Color(red: 1.0, green: 0.55, blue: 0.3))
                        HorizontalFluidWave(time: time, fromTop: wave2FromTop, baseHeight: 0.6, amplitude: 50, frequency: 1.1, speed: 0.75 * speedMultiplier2, color: Color(red: 1.0, green: 0.45, blue: 0.4))
                        HorizontalFluidWave(time: time, fromTop: wave3FromTop, baseHeight: 0.35, amplitude: 45, frequency: 1.3, speed: 0.9 * speedMultiplier3, color: Color(red: 1.0, green: 0.35, blue: 0.5))
                    }
                }
                .drawingGroup()
            }
        }
        .onAppear {
            wave1FromTop = Bool.random()
            wave2FromTop = Bool.random()
            wave3FromTop = Bool.random()
            speedMultiplier1 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
            speedMultiplier2 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
            speedMultiplier3 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
        }
        .ignoresSafeArea()
    }
}

struct HorizontalFluidWave: View {
    let time: Double
    let fromTop: Bool
    let baseHeight: CGFloat
    let amplitude: CGFloat
    let frequency: CGFloat
    let speed: CGFloat
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            HorizontalFluidShape(time: time, fromTop: fromTop, baseHeight: baseHeight, amplitude: amplitude, frequency: frequency, speed: speed)
                .fill(color)
        }
    }
}

struct HorizontalFluidShape: Shape {
    var time: Double
    var fromTop: Bool
    var baseHeight: CGFloat
    var amplitude: CGFloat
    var frequency: CGFloat
    var speed: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = 80
        
        if fromTop {
            let waveY = rect.height * baseHeight
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            
            for i in (0...steps).reversed() {
                let x = (CGFloat(i) / CGFloat(steps)) * rect.width
                let normalizedX = x / rect.width
                let wave1 = sin((normalizedX * .pi * 2 * frequency) + (time * speed)) * amplitude
                let wave2 = sin((normalizedX * .pi * 3.5 * frequency) + (time * speed * 1.3)) * (amplitude * 0.3)
                let wave3 = cos((normalizedX * .pi * 1.5 * frequency) + (time * speed * 0.7)) * (amplitude * 0.2)
                let y = waveY + wave1 + wave2 + wave3
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.closeSubpath()
        } else {
            let waveY = rect.height * (1 - baseHeight)
            path.move(to: CGPoint(x: 0, y: rect.height))
            
            for i in 0...steps {
                let x = (CGFloat(i) / CGFloat(steps)) * rect.width
                let normalizedX = x / rect.width
                let wave1 = sin((normalizedX * .pi * 2 * frequency) + (time * speed)) * amplitude
                let wave2 = sin((normalizedX * .pi * 3.5 * frequency) + (time * speed * 1.3)) * (amplitude * 0.3)
                let wave3 = cos((normalizedX * .pi * 1.5 * frequency) + (time * speed * 0.7)) * (amplitude * 0.2)
                let y = waveY + wave1 + wave2 + wave3
                path.addLine(to: CGPoint(x: x, y: y))
            }
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Picker Screen
struct PickerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @Binding var choicesMade: Bool
    @Binding var showTimerFlow: Bool
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: AppSettings
    @Environment(\.colorScheme) var colorScheme

    @State private var showContent = false
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                AnimatedMeshBackground()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    if !choicesMade {
                        // Titles above pickers
                        HStack(spacing: 12) {
                            Text("Lock In Time")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                            
                            Text("Chill Time")
                                .font(.title2.weight(.bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        
                        // Pickers side by side
                        HStack(spacing: 12) {
                            ModernPickerCard(
                                selection: $studyTime,
                                height: isLandscape ? geo.size.height * 0.5 : geo.size.height * 0.65
                            )
                            
                            ModernPickerCard(
                                selection: $restTime,
                                height: isLandscape ? geo.size.height * 0.5 : geo.size.height * 0.65
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // Done button
                        Button {
                            choicesMade = true
                        } label: {
                            Text("Done")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(.blue.opacity(0.7))
                                        .overlay(
                                            Capsule()
                                                .stroke(.white, lineWidth: 2)
                                        )
                                )
                                .shadow(radius: 10)
                        }
                        .padding(.top, 24)
                    }
                    
                    Spacer()
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showContent)
                
                // Back button
                VStack {
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { showTimerFlow = false }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 24, height: 24)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                )
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 8)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width > 50 && abs(value.translation.height) < 100 {
                        withAnimation(.easeInOut(duration: 0.25)) { showTimerFlow = false }
                    }
                }
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showContent = true }
        }
    }
}

// MARK: - Modern Picker Card
struct ModernPickerCard: View {
    @Binding var selection: Int
    let height: CGFloat
    @Environment(\.colorScheme) var colorScheme
    @State private var scrollPosition: Int?

    private let itemHeight: CGFloat = 50

    private func pixelAlign(_ value: CGFloat) -> CGFloat {
        let scale = UIScreen.main.scale
        return (value * scale).rounded() / scale
    }

    var body: some View {
        GeometryReader { geo in
            let inset = pixelAlign(max(0, (geo.size.height - itemHeight) / 2))

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial.opacity(colorScheme == .light ? 0.25 : 1))

                // Scrollable numbers (no spacer rows)
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(1...60, id: \.self) { num in
                            Text("\(num)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(scrollPosition == num ? .white : .white.opacity(0.4))
                                .frame(height: itemHeight)
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                                .id(num)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.vertical, inset, for: .scrollContent)
                .scrollPosition(id: $scrollPosition, anchor: .center)
                .scrollTargetBehavior(.viewAligned)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.25),
                            .init(color: .white, location: 0.75),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Selector overlay
                LiquidGlassSelector(height: itemHeight)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .task {
            // Keep in range just in case
            selection = min(max(selection, 1), 60)
            scrollPosition = selection
        }
        .onChange(of: scrollPosition) { _, newValue in
            if let v = newValue { selection = v }
        }
        .onChange(of: selection) { _, newValue in
            let v = min(max(newValue, 1), 60)
            if scrollPosition != v { scrollPosition = v }
        }
    }
}

struct LiquidGlassSelector: View {
    let height: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height * 0.42, style: .continuous)

        shape
            .fill(.ultraThinMaterial)
            .opacity(0.08)
            .overlay(      // highlight (keep subtle)
                shape.fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.10),
                            .white.opacity(0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.overlay)
            )
            .overlay(shape.stroke(.white.opacity(0.22), lineWidth: 1))
            .shadow(color: .black.opacity(0.20), radius: 14, x: 0, y: 10)
            .frame(height: height)
            .padding(.horizontal, 10)
    }
}

// MARK: - Timer Screen
struct TimerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @Binding var choicesMade: Bool
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsManager
    @ObservedObject var soundManager: FocusSoundManager
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    @State private var isStudy = true
    @State private var secondsLeft: Int
    @State private var timerRunning = false
    @State private var sessionComplete = false
    @State private var consecutiveSessions = 0
    @State private var isLongBreak = false
    @State private var studySecondsThisSession = 0
    
    @State private var timerStartTime: Date?
    @State private var timerEndTime: Date?
    @State private var backgroundTime: Date?
    @State private var audioPlayer: AVAudioPlayer?
    
    @StateObject private var cameraManager = CameraManager()
    @State private var showCameraPreview = false
    @State private var timelapseMessage: String?
    @State private var showTimelapseAlert = false
    @State private var showSettings = false
    @State private var showUI = true
    @State private var hideTimer: Timer?
    @State private var cameraPreviewHidden = false
    @State private var batterySaverMode = false
    
    @StateObject private var motionManager = MotionManager()
    @StateObject private var liveActivityManager = LiveActivityManager()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(studyTime: Binding<Int>, restTime: Binding<Int>, choicesMade: Binding<Bool>, settings: AppSettings, stats: StatsManager, soundManager: FocusSoundManager) {
        self._studyTime = studyTime
        self._restTime = restTime
        self._choicesMade = choicesMade
        self._settings = ObservedObject(wrappedValue: settings)
        self._stats = ObservedObject(wrappedValue: stats)
        self._soundManager = ObservedObject(wrappedValue: soundManager)
        self._secondsLeft = State(initialValue: studyTime.wrappedValue * 60)
    }
    
    var totalSeconds: Int {
        if isStudy { return studyTime * 60 }
        else if isLongBreak { return settings.longBreakTime * 60 }
        else { return restTime * 60 }
    }
    
    var progress: CGFloat { CGFloat(totalSeconds - secondsLeft) / CGFloat(totalSeconds) }
    
    var studyGradient: LinearGradient {
        LinearGradient(colors: [settings.studyColor.opacity(0.7), settings.studyColor], startPoint: .leading, endPoint: .trailing)
    }
    
    var restGradient: LinearGradient {
        LinearGradient(colors: [settings.restColor.opacity(0.7), settings.restColor], startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if batterySaverMode {
                    Color.black.ignoresSafeArea()
                } else {
                    (isStudy ? settings.studyBackgroundColor : settings.restBackgroundColor).ignoresSafeArea()
                    FluidFillView(progress: progress, gradient: isStudy ? studyGradient : restGradient, motionManager: motionManager, isAnimating: timerRunning)
                }
                
                VStack(spacing: 30) {
                    if !batterySaverMode {
                        VStack(spacing: 8) {
                            Text(isStudy ? "Lock In Time" : (isLongBreak ? "Long Chill" : "Chill Time"))
                                .font(.largeTitle).bold().foregroundColor(.white)
                            if settings.longBreakEnabled {
                                Text("Session \(consecutiveSessions + 1) of \(settings.sessionsUntilLongBreak)")
                                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                    
                    Text(timeString(from: secondsLeft))
                        .font(.system(size: batterySaverMode ? 90 : 70, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    if showUI && !batterySaverMode {
                        HStack(spacing: 16) {
                            Button { toggleTimer() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                    Text(timerRunning ? "Pause" : "Start").bold()
                                }.foregroundColor(.white)
                            }
                            .buttonStyle(GlassButtonStyle(isActive: timerRunning, activeColor: .green))
                            
                            Button { resetTimer() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset").bold()
                                }.foregroundColor(.white)
                            }
                            .buttonStyle(GlassButtonStyle())
                            
                            Button { toggleTimelapse() } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: cameraManager.isRecording ? "video.fill" : "video")
                                    Text(cameraManager.isRecording ? "Rec" : "Timelapse").bold()
                                }.foregroundColor(.white)
                            }
                            .buttonStyle(GlassButtonStyle(isActive: cameraManager.isRecording, activeColor: .red))
                        }
                        .transition(.opacity)
                    }
                    
                    if showUI && !batterySaverMode && soundManager.currentSound != nil && soundManager.isPlaying {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                            Text(soundManager.currentSound?.displayName ?? "")
                        }
                        .font(.caption).foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.15)))
                        .transition(.opacity)
                    }
                }
                
                if showCameraPreview && !cameraPreviewHidden && !batterySaverMode {
                    DraggableCameraPreview(cameraManager: cameraManager, isHidden: $cameraPreviewHidden)
                }
                
                if showUI {
                    HStack {
                        Spacer()
                        VStack {
                            if !isLandscape { Spacer().frame(height: 8) } else { Spacer() }
                            
                            VStack(spacing: 12) {
                                Button {
                                    if cameraManager.isRecording { cameraManager.stopRecording() }
                                    cameraManager.cleanup()
                                    showCameraPreview = false
                                    liveActivityManager.endActivity()
                                    resetTimer()
                                    choicesMade = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 18, weight: .semibold))
                                        .frame(width: 24, height: 24).foregroundColor(.white)
                                        .padding(12)
                                        .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1)))
                                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                }
                                
                                if !batterySaverMode {
                                    Button {
                                        withAnimation(.spring(response: 0.4)) { showSettings = true }
                                        showUITemporarily()
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .font(.system(size: 20)).frame(width: 24, height: 24).foregroundColor(.white)
                                            .padding(12)
                                            .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1)))
                                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                    }
                                }
                                
                                if showCameraPreview && cameraPreviewHidden && !batterySaverMode {
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { cameraPreviewHidden = false }
                                    } label: {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 18)).frame(width: 24, height: 24).foregroundColor(.white)
                                            .padding(12)
                                            .background(Circle().fill(.ultraThinMaterial).overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1)))
                                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                    }
                                }
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) { batterySaverMode.toggle() }
                                } label: {
                                    Image(systemName: batterySaverMode ? "sun.max.fill" : "moon.fill")
                                        .font(.system(size: 20)).frame(width: 24, height: 24)
                                        .foregroundColor(batterySaverMode ? .yellow : .white)
                                        .padding(12)
                                        .background(Circle().fill(.ultraThinMaterial).opacity(batterySaverMode ? 0.3 : 1.0)
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1)))
                                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                                }
                            }
                            
                            if isLandscape { Spacer() } else { Spacer() }
                        }
                        .padding(.trailing, 20)
                    }
                    .transition(.opacity)
                }
                
                if showSettings && !batterySaverMode {
                    SettingsPanel(settings: settings, soundManager: soundManager, isPresented: $showSettings)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .onTapGesture { showUITemporarily() }
        .onAppear {
            showUITemporarily()
            restoreTimerStateIfNeeded()
        }
        .onReceive(timer) { _ in
            guard timerRunning, let endTime = timerEndTime else { return }
            
            let remaining = Int(endTime.timeIntervalSince(Date()))
            
            if remaining > 0 {
                // Track study time based on change
                if isStudy {
                    let studied = secondsLeft - remaining
                    if studied > 0 { studySecondsThisSession += studied }
                }
                secondsLeft = remaining
            } else {
                secondsLeft = 0
                timerCompleted()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            updateTimerFromBackground()
            if timerRunning && !batterySaverMode { motionManager.startMotionUpdates() }
            
            // Resume camera if it was active
            if showCameraPreview {
                cameraManager.resumeSession()
            }
            
            // If timer is not running, clean up any orphaned Live Activities
            if !timerRunning {
                liveActivityManager.cleanupOrphanedActivities()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if timerRunning {
                backgroundTime = Date()
                // Save timer state in case iOS kills the app
                TimerStateManager.shared.saveState(
                    timerRunning: timerRunning,
                    isStudy: isStudy,
                    timerStartTime: timerStartTime,
                    timerEndTime: timerEndTime,
                    consecutiveSessions: consecutiveSessions,
                    isLongBreak: isLongBreak,
                    studyTime: studyTime,
                    restTime: restTime
                )
            }
            motionManager.stopMotionUpdates()
            // Pause camera to save memory/battery in background
            cameraManager.pauseSession()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            // Save state but keep Live Activity running
            if timerRunning {
                TimerStateManager.shared.saveState(
                    timerRunning: timerRunning,
                    isStudy: isStudy,
                    timerStartTime: timerStartTime,
                    timerEndTime: timerEndTime,
                    consecutiveSessions: consecutiveSessions,
                    isLongBreak: isLongBreak,
                    studyTime: studyTime,
                    restTime: restTime
                )
            }
        }
        .alert("Timelapse", isPresented: $showTimelapseAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text(timelapseMessage ?? "") }
        .onChange(of: studyTime) { _, newValue in
            if !timerRunning && isStudy { secondsLeft = newValue * 60 }
        }
        .onChange(of: restTime) { _, newValue in
            if !timerRunning && !isStudy && !isLongBreak { secondsLeft = newValue * 60 }
        }
        .onChange(of: batterySaverMode) { _, newValue in
            if newValue { motionManager.stopMotionUpdates() }
            else if timerRunning { motionManager.startMotionUpdates() }
        }
        .onChange(of: choicesMade) { _, newValue in
            if !newValue {
                if cameraManager.isRecording { cameraManager.stopRecording() }
                cameraManager.cleanup()
                showCameraPreview = false
                liveActivityManager.endActivity()
            }
        }
        .onDisappear {
            if cameraManager.isRecording { cameraManager.stopRecording() }
            cameraManager.cleanup()
            showCameraPreview = false
            soundManager.stop()
            motionManager.stopMotionUpdates()
            liveActivityManager.endActivity()
        }
    }
    
    func showUITemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) { showUI = true }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { showUI = false }
        }
    }
    
    func restoreTimerStateIfNeeded() {
        guard let state = TimerStateManager.shared.loadState() else { return }
        guard let endTime = state.timerEndTime else { return }
        
        let remaining = Int(endTime.timeIntervalSince(Date()))
        
        if remaining > 0 {
            // Timer is still running - restore state
            isStudy = state.isStudy
            timerStartTime = state.timerStartTime
            timerEndTime = state.timerEndTime
            consecutiveSessions = state.consecutiveSessions
            isLongBreak = state.isLongBreak
            secondsLeft = remaining
            timerRunning = true
            
            // Restart Live Activity with correct state
            if let startTime = timerStartTime {
                liveActivityManager.startActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, sessionNumber: consecutiveSessions + 1,
                                                 totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
            }
            
            print("♻️ Timer state restored: isStudy=\(isStudy), remaining=\(remaining)s")
        } else {
            // Timer completed while app was killed - handle phase transitions
            var currentEndTime = endTime
            var currentIsStudy = state.isStudy
            var currentConsecutiveSessions = state.consecutiveSessions
            var currentIsLongBreak = state.isLongBreak
            let savedStudyTime = state.studyTime > 0 ? state.studyTime : studyTime
            let savedRestTime = state.restTime > 0 ? state.restTime : restTime
            
            // Calculate how many phases have completed
            while currentEndTime.timeIntervalSince(Date()) <= 0 {
                if currentIsStudy {
                    currentConsecutiveSessions += 1
                    if settings.longBreakEnabled && currentConsecutiveSessions >= settings.sessionsUntilLongBreak {
                        currentIsLongBreak = true
                        currentConsecutiveSessions = 0
                        currentEndTime = currentEndTime.addingTimeInterval(TimeInterval(settings.longBreakTime * 60))
                    } else {
                        currentIsLongBreak = false
                        currentEndTime = currentEndTime.addingTimeInterval(TimeInterval(savedRestTime * 60))
                    }
                    currentIsStudy = false
                } else {
                    currentIsStudy = true
                    currentIsLongBreak = false
                    currentEndTime = currentEndTime.addingTimeInterval(TimeInterval(savedStudyTime * 60))
                }
            }
            
            // Set new state
            isStudy = currentIsStudy
            consecutiveSessions = currentConsecutiveSessions
            isLongBreak = currentIsLongBreak
            timerStartTime = Date()
            timerEndTime = currentEndTime
            secondsLeft = Int(currentEndTime.timeIntervalSince(Date()))
            timerRunning = true
            
            // Start fresh Live Activity
            liveActivityManager.startActivity(startTime: timerStartTime!, endTime: timerEndTime!, isStudy: isStudy, sessionNumber: consecutiveSessions + 1,
                                             totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
            
            print("♻️ Timer state restored after completion: isStudy=\(isStudy), remaining=\(secondsLeft)s")
        }
        
        // Clear saved state since we've restored it
        TimerStateManager.shared.clearState()
    }
    
    func toggleTimer() {
        timerRunning.toggle()
        
        if timerRunning {
            timerStartTime = Date()
            timerEndTime = Date().addingTimeInterval(TimeInterval(secondsLeft))
            scheduleTimerEndNotification()
            if !batterySaverMode { motionManager.startMotionUpdates() }
            if isStudy && soundManager.currentSound != nil && !soundManager.isPlaying { soundManager.play() }
            
            let startTime = timerStartTime!
            let endTime = timerEndTime!
            print("🟡 Timer started - attempting to start Live Activity...")
            print("   - secondsLeft: \(secondsLeft)")
            print("   - startTime: \(startTime)")
            print("   - endTime: \(endTime)")
            liveActivityManager.startActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, sessionNumber: consecutiveSessions + 1,
                                             totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
        } else {
            cancelScheduledNotifications()
            timerStartTime = nil
            timerEndTime = nil
            motionManager.stopMotionUpdates()
            
            let endTime = Date().addingTimeInterval(TimeInterval(secondsLeft))
            let startTime = Date()
            liveActivityManager.updateActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, isPaused: true,
                                              sessionNumber: consecutiveSessions + 1,
                                              totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
        }
    }
    
    func resetTimer() {
        timerRunning = false
        isStudy = true
        isLongBreak = false
        secondsLeft = studyTime * 60
        timerStartTime = nil
        timerEndTime = nil
        backgroundTime = nil
        sessionComplete = false
        studySecondsThisSession = 0
        cancelScheduledNotifications()
        soundManager.stop()
        motionManager.stopMotionUpdates()
        liveActivityManager.endActivity()
        TimerStateManager.shared.clearState()
    }
    
    func timerCompleted() {
        if !settings.isMuted { playDingSound() }
        cancelScheduledNotifications()
        scheduleCompletionNotification()
        
        let wasStudy = isStudy
        
        if wasStudy {
            stats.addStudyTime(seconds: studySecondsThisSession)
            studySecondsThisSession = 0
            consecutiveSessions += 1
            soundManager.pause()
            
            if settings.longBreakEnabled && consecutiveSessions >= settings.sessionsUntilLongBreak {
                isLongBreak = true
                consecutiveSessions = 0
                secondsLeft = settings.longBreakTime * 60
            } else {
                isLongBreak = false
                secondsLeft = restTime * 60
            }
            isStudy = false
        } else {
            isStudy = true
            isLongBreak = false
            secondsLeft = studyTime * 60
            if timerRunning && soundManager.currentSound != nil { soundManager.play() }
        }
        
        if timerRunning {
            timerStartTime = Date()
            timerEndTime = Date().addingTimeInterval(TimeInterval(secondsLeft))
            scheduleTimerEndNotification()
            let startTime = timerStartTime!
            let endTime = timerEndTime!
            print("🔄 Timer completed - switching mode:")
            print("   - wasStudy: \(wasStudy), nowStudy: \(isStudy)")
            print("   - new secondsLeft: \(secondsLeft)")
            print("   - startTime: \(startTime)")
            print("   - endTime: \(endTime)")
            
            liveActivityManager.updateActivity(startTime: startTime, endTime: endTime, isStudy: isStudy, isPaused: false,
                                              sessionNumber: consecutiveSessions + 1,
                                              totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
        }
    }
    
    var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    
    func toggleTimelapse() {
        if isSimulator {
            timelapseMessage = "Timelapse requires a real device."
            showTimelapseAlert = true
            return
        }
        
        if cameraManager.isRecording {
            cameraManager.onTimelapseComplete = { url in
                timelapseMessage = url != nil ? "Timelapse saved to your photo library!" : "Could not create timelapse."
                showTimelapseAlert = true
            }
            cameraManager.stopRecording()
            showCameraPreview = false
        } else {
            cameraManager.requestPermission { granted in
                if granted {
                    cameraManager.setupCamera()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCameraPreview = true
                        cameraManager.startRecording()
                        cameraManager.onTimelapseComplete = { url in
                            timelapseMessage = url != nil ? "Timelapse saved!" : "Could not create timelapse."
                            showTimelapseAlert = true
                        }
                    }
                } else {
                    timelapseMessage = "Camera access required for timelapse."
                    showTimelapseAlert = true
                }
            }
        }
    }
    
    func updateTimerFromBackground() {
        guard let backgroundTime = backgroundTime, timerRunning, let endTime = timerEndTime else { return }
        
        // Calculate remaining time from the original endTime
        let remaining = Int(endTime.timeIntervalSince(Date()))
        
        if remaining <= 0 {
            // Timer completed while in background
            secondsLeft = 0
            timerCompleted()
        } else {
            // Update secondsLeft from endTime (keeps it in sync)
            let previousSecondsLeft = secondsLeft
            secondsLeft = remaining
            
            // Track study time
            if isStudy {
                let studied = previousSecondsLeft - remaining
                if studied > 0 { studySecondsThisSession += studied }
            }
            
            // Update Live Activity to ensure it's in sync - use original startTime
            if let startTime = timerStartTime {
                liveActivityManager.updateActivity(startTime: startTime, endTime: timerEndTime!, isStudy: isStudy, isPaused: false,
                                                  sessionNumber: consecutiveSessions + 1,
                                                  totalSessions: settings.longBreakEnabled ? settings.sessionsUntilLongBreak : 4)
            }
        }
        self.backgroundTime = nil
    }
    
    func scheduleTimerEndNotification() {
        cancelScheduledNotifications()
        guard secondsLeft > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Lock In Time Complete!" : "Chill Time Complete!"
        content.body = isStudy ? "Time for a break!" : "Time to study!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsLeft), repeats: false)
        let request = UNNotificationRequest(identifier: "timer_end", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Lock In Time Done!" : "Chill Time Done!"
        content.body = isStudy ? "Time to rest!" : "Time to study!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_completed_\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
    
    func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_end", "timer_completed"])
    }
    
    func timeString(from seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    
    func playDingSound() {
        if let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") {
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try AVAudioSession.sharedInstance().setActive(true)
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                return
            } catch { }
        }
        AudioServicesPlaySystemSound(1007)
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var studyTime = 25
    @State private var restTime = 5
    @State private var choicesMade = false
    @State private var showLogoScreen = false
    @State private var showTimerFlow = false
    @StateObject private var settings = AppSettings()
    @StateObject private var stats = StatsManager()
    @StateObject private var soundManager = FocusSoundManager()

    init() {
        let logoViewCount = UserDefaults.standard.integer(forKey: "logoViewCount")
        // Check if there's a saved timer running - skip logo screen
        let timerRunning = UserDefaults.standard.bool(forKey: "timerRunning")
        _showLogoScreen = State(initialValue: !timerRunning && logoViewCount < 2)
        _showTimerFlow = State(initialValue: timerRunning)
        _choicesMade = State(initialValue: timerRunning)
        
        // Restore study/rest times
        let savedStudyTime = UserDefaults.standard.integer(forKey: "savedStudyTime")
        let savedRestTime = UserDefaults.standard.integer(forKey: "savedRestTime")
        if savedStudyTime > 0 { _studyTime = State(initialValue: savedStudyTime) }
        if savedRestTime > 0 { _restTime = State(initialValue: savedRestTime) }
    }

    var body: some View {
        ZStack {
            if showLogoScreen {
                LogoScreen(isFinished: $showLogoScreen)
                    .transition(.opacity)
            } else if !showTimerFlow {
                TrackerView(showTimer: $showTimerFlow, stats: stats, settings: settings)
                    .transition(.opacity)
            } else if !choicesMade {
                PickerScreen(studyTime: $studyTime, restTime: $restTime, choicesMade: $choicesMade, showTimerFlow: $showTimerFlow, stats: stats, settings: settings)
                    .transition(.opacity)
            } else {
                TimerScreen(studyTime: $studyTime, restTime: $restTime, choicesMade: $choicesMade, settings: settings, stats: stats, soundManager: soundManager)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showLogoScreen)
        .animation(.easeInOut(duration: 0.25), value: showTimerFlow)
        .animation(.easeInOut(duration: 0.25), value: choicesMade)
        .onAppear {
            requestNotificationPermission()
            // Clean up any orphaned Live Activities if not in timer flow
            if !showTimerFlow {
                LiveActivityManager.shared.cleanupOrphanedActivities()
            }
        }
        .onChange(of: showTimerFlow) { oldValue, newValue in
            if newValue {
                OrientationManager.shared.unlock()
            } else {
                OrientationManager.shared.lockToPortrait()
                // Clean up any Live Activities and saved state when leaving timer flow
                LiveActivityManager.shared.cleanupOrphanedActivities()
                TimerStateManager.shared.clearState()
            }
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted { print("Notifications allowed") }
            else if let error = error { print("Error requesting notifications: \(error)") }
        }
    }
}

#Preview {
    ContentView()
}
