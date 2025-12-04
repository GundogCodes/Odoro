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

// MARK: - Motion Manager for Gyroscope
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0  // Forward/back tilt
    @Published var roll: Double = 0   // Left/right tilt
    
    init() {
        startMotionUpdates()
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.deviceMotionUpdateInterval = 1/60
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }
            
            withAnimation(.easeOut(duration: 0.1)) {
                self?.pitch = motion.attitude.pitch
                self?.roll = motion.attitude.roll
            }
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
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
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            FluidShape(
                progress: progress,
                waveOffset: CGFloat(time * 1.5), // Smooth continuous wave
                waveHeight: 12 + CGFloat(abs(motionManager.roll)) * 15, // Wave height responds to roll
                tiltOffset: CGFloat(motionManager.roll) // Tilt responds to device roll
            )
            .fill(gradient)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 5, y: 0)
        }
        .ignoresSafeArea()
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
    @Published var sessionsCompleted: Int {
        didSet { save() }
    }
    @Published var currentStreak: Int {
        didSet { save() }
    }
    @Published var lastStudyDate: Date? {
        didSet { save() }
    }
    
    private let defaults = UserDefaults.standard
    
    init() {
        self.todayStudySeconds = defaults.integer(forKey: "todayStudySeconds")
        self.weekStudySeconds = defaults.integer(forKey: "weekStudySeconds")
        self.sessionsCompleted = defaults.integer(forKey: "sessionsCompleted")
        self.currentStreak = defaults.integer(forKey: "currentStreak")
        if let date = defaults.object(forKey: "lastStudyDate") as? Date {
            self.lastStudyDate = date
        } else {
            self.lastStudyDate = nil
        }
        checkAndResetIfNeeded()
    }
    
    func save() {
        defaults.set(todayStudySeconds, forKey: "todayStudySeconds")
        defaults.set(weekStudySeconds, forKey: "weekStudySeconds")
        defaults.set(sessionsCompleted, forKey: "sessionsCompleted")
        defaults.set(currentStreak, forKey: "currentStreak")
        if let date = lastStudyDate {
            defaults.set(date, forKey: "lastStudyDate")
        }
    }
    
    func checkAndResetIfNeeded() {
        let calendar = Calendar.current
        let now = Date()
        
        // Reset daily stats if it's a new day
        if let lastDate = lastStudyDate {
            if !calendar.isDateInToday(lastDate) {
                todayStudySeconds = 0
                
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
            }
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
        sessionsCompleted += 1
        lastStudyDate = now
    }
    
    var todayFormatted: String {
        formatTime(seconds: todayStudySeconds)
    }
    
    var weekFormatted: String {
        formatTime(seconds: weekStudySeconds)
    }
    
    private func formatTime(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
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
        
        // Try to load from bundle
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: "mp3") else {
            print("Sound file not found: \(sound.fileName).mp3")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop forever
            audioPlayer?.volume = volume
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
    }
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    // Default colors
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

// MARK: - Camera Manager for Timelapse
class CameraManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var previewImage: UIImage?
    @Published var capturedFrames: [UIImage] = []
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var captureTimer: Timer?
    private let captureInterval: TimeInterval = 0.5 // Capture every 0.5 seconds for smoother timelapse
    private var lastCaptureTime: Date = Date()
    private var shouldCaptureFrame = false
    
    private let sessionQueue = DispatchQueue(label: "cameraSessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "videoOutputQueue")
    
    var onTimelapseComplete: ((URL?) -> Void)?
    
    override init() {
        super.init()
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
        captureSession?.sessionPreset = .high
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("Failed to access front camera")
            return
        }
        
        if captureSession?.canAddInput(input) == true {
            captureSession?.addInput(input)
        }
        
        // Use video output for smooth preview
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput?.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput?.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoOutput?.alwaysDiscardsLateVideoFrames = true
        
        if let videoOutput = videoOutput, captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
            
            // Fix orientation
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
            self.capturedFrames.removeAll()
            self.lastCaptureTime = Date()
        }
        
        // Start capture timer
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.shouldCaptureFrame = true
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        captureTimer?.invalidate()
        captureTimer = nil
        
        // Create video on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if self.capturedFrames.count > 1 {
                self.createTimelapseVideo()
            } else {
                DispatchQueue.main.async {
                    self.onTimelapseComplete?(nil)
                }
            }
        }
    }
    
    private func createTimelapseVideo() {
        guard !capturedFrames.isEmpty else {
            DispatchQueue.main.async { self.onTimelapseComplete?(nil) }
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("timelapse_\(Date().timeIntervalSince1970).mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let firstImage = capturedFrames.first else {
            DispatchQueue.main.async { self.onTimelapseComplete?(nil) }
            return
        }
        
        let size = firstImage.size
        
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            DispatchQueue.main.async { self.onTimelapseComplete?(nil) }
            return
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width,
            AVVideoHeightKey: size.height
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height
            ]
        )
        
        writer.add(writerInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // 30fps playback for smooth timelapse
        let frameDuration = CMTime(value: 1, timescale: 30)
        var frameCount: Int64 = 0
        
        for image in capturedFrames {
            while !writerInput.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            
            if let buffer = pixelBuffer(from: image) {
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                adaptor.append(buffer, withPresentationTime: presentationTime)
            }
            frameCount += 1
        }
        
        writerInput.markAsFinished()
        
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()
        
        if writer.status == .completed {
            saveToPhotoLibrary(url: outputURL)
        } else {
            DispatchQueue.main.async { self.onTimelapseComplete?(nil) }
        }
    }
    
    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let size = image.size
        var pixelBuffer: CVPixelBuffer?
        
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                           kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )
        
        if let cgImage = image.cgImage {
            context?.draw(cgImage, in: CGRect(origin: .zero, size: size))
        }
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
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
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
        captureTimer?.invalidate()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            // Always update preview for smooth video feed
            self.previewImage = image
            
            // Capture frame for timelapse if recording and timer triggered
            if self.isRecording && self.shouldCaptureFrame {
                self.capturedFrames.append(image)
                self.shouldCaptureFrame = false
            }
        }
    }
}

// MARK: - Draggable Camera Preview
struct DraggableCameraPreview: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var position: CGPoint = CGPoint(x: 80, y: 150)
    @State private var dragOffset: CGSize = .zero
    @State private var recordingDuration: Int = 0
    @State private var recordingTimer: Timer?
    
    var body: some View {
        ZStack {
            // Main container with glass effect
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                          startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 0) {
                // Camera viewfinder
                ZStack {
                    if let image = cameraManager.previewImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 130, height: 170)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(.black)
                            .frame(width: 130, height: 170)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    
                    // Viewfinder corner brackets
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
                    
                    // Recording indicator overlay
                    if cameraManager.isRecording {
                        VStack {
                            HStack {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: .red, radius: 3)
                                    Text("REC")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(.black.opacity(0.6)))
                                
                                Spacer()
                                
                                Text(formatDuration(recordingDuration))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.black.opacity(0.6)))
                            }
                            .padding(6)
                            
                            Spacer()
                        }
                        .frame(width: 130, height: 170)
                    }
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
        }
        .onDisappear {
            recordingTimer?.invalidate()
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
            if cameraManager.isRecording {
                recordingDuration += 1
            }
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// Viewfinder corner bracket
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
            // Blur background instead of dark overlay
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) { isPresented = false }
                }
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4)) { isPresented = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Tab Picker
                Picker("", selection: $selectedTab) {
                    Text("General").tag(0)
                    Text("Sounds").tag(1)
                    Text("Tips").tag(2)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        if selectedTab == 0 {
                            generalSettings
                        } else if selectedTab == 1 {
                            soundSettings
                        } else {
                            tipsSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .frame(maxWidth: 380, maxHeight: 520)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28).fill(.ultraThinMaterial)
                    // Dark tint for better text contrast
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
            // Fill Colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Fill Colors")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Lock In Fill")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.studyColor, supportsOpacity: false)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Chill Fill")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.restColor, supportsOpacity: false)
                        .labelsHidden()
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            // Background Colors
            VStack(alignment: .leading, spacing: 12) {
                Text("Background Colors")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack {
                    Text("Lock In Background")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.studyBackgroundColor, supportsOpacity: true)
                        .labelsHidden()
                }
                
                HStack {
                    Text("Chill Background")
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    ColorPicker("", selection: $settings.restBackgroundColor, supportsOpacity: true)
                        .labelsHidden()
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            // Reset to Defaults Button
            Button {
                withAnimation {
                    settings.resetToDefaults()
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Reset Colors to Default")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.15)))
            }
            
            // Long Chill Settings
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $settings.longBreakEnabled) {
                    Text("Long Chill")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .tint(.orange)
                
                Text("Take an extended chill session after completing multiple lock in sessions. This follows the Pomodoro technique to prevent burnout.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                if settings.longBreakEnabled {
                    HStack {
                        Text("After")
                            .foregroundColor(.white.opacity(0.8))
                        Picker("", selection: $settings.sessionsUntilLongBreak) {
                            ForEach(2...8, id: \.self) { num in
                                Text("\(num) sessions").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }
                    
                    HStack {
                        Text("Duration")
                            .foregroundColor(.white.opacity(0.8))
                        Picker("", selection: $settings.longBreakTime) {
                            ForEach([10, 15, 20, 25, 30], id: \.self) { num in
                                Text("\(num) min").tag(num)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                    }
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            // Mute Toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mute Sound")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Silence the ding")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                Spacer()
                Toggle("", isOn: $settings.isMuted)
                    .labelsHidden()
                    .tint(.orange)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        }
    }
    
    var soundSettings: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Focus Sounds")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Plays during study, pauses on break")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                // Sound options
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FocusSoundManager.FocusSound.allCases, id: \.rawValue) { sound in
                        Button {
                            if soundManager.currentSound == sound {
                                soundManager.setSound(nil)
                            } else {
                                soundManager.setSound(sound)
                            }
                        } label: {
                            Text(sound.displayName)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(soundManager.currentSound == sound ? .blue.opacity(0.5) : .white.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(soundManager.currentSound == sound ? .blue : .clear, lineWidth: 2)
                                )
                        }
                    }
                }
                
                // None option
                Button {
                    soundManager.setSound(nil)
                } label: {
                    Text("🔇 None")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(soundManager.currentSound == nil ? .blue.opacity(0.5) : .white.opacity(0.15))
                        )
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            // Volume
            if soundManager.currentSound != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Volume")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.white.opacity(0.6))
                        Slider(value: $soundManager.volume, in: 0...1)
                            .tint(.blue)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            }
            
            // Note about audio files
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Audio Files")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                Text("Add audio files (rain.mp3, lofi.mp3, etc.) to your app bundle to enable focus sounds.")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.blue.opacity(0.15)))
        }
    }
    
    var tipsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text("Study Tip")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Text(currentTip)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                Button {
                    withAnimation {
                        currentTip = StudyTips.randomTip()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("New Tip")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.blue.opacity(0.5)))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
            
            // Quick facts
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick Facts")
                    .font(.headline)
                    .foregroundColor(.white)
                
                FactRow(icon: "brain.head.profile", text: "Your brain can only focus for 90-120 minutes at a time")
                FactRow(icon: "clock.fill", text: "The ideal study session is 25-50 minutes")
                FactRow(icon: "bed.double.fill", text: "Memory consolidation happens during sleep")
                FactRow(icon: "figure.walk", text: "Walking boosts creativity by up to 60%")
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.1)))
        }
    }
}

struct FactRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 24)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Logo Screen
struct LogoScreen: View {
    @Binding var isFinished: Bool
    @State private var jumpUp = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.white, .orange], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Image("logo2")
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 90, maxWidth:120)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white, lineWidth: 6)
                        )
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
                }
                .padding(.top, 100)

                Text("Your study buddy")
                    .padding(.top, 100)
                    .font(.headline).bold()
                    .foregroundStyle(.regularMaterial)
            }
        }
    }
}

// MARK: - Animated Mesh Background
struct AnimatedMeshBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Randomized on each load
    @State private var wave1FromTop: Bool = false
    @State private var wave2FromTop: Bool = true
    @State private var wave3FromTop: Bool = false
    @State private var speedMultiplier1: Double = 1.0
    @State private var speedMultiplier2: Double = 1.0
    @State private var speedMultiplier3: Double = 1.0
    @State private var initialized = false
    
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            GeometryReader { geo in
                ZStack {
                    if colorScheme == .dark {
                        // Solid dark cyan base
                        Color(red: 0.0, green: 0.45, blue: 0.4)
                        
                        // Wave 1 - brighter green
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave1FromTop,
                            baseHeight: 0.65,
                            amplitude: 50,
                            frequency: 1.0,
                            speed: 0.6 * speedMultiplier1,
                            color: Color(red: 0.0, green: 0.7, blue: 0.5)
                        )
                        
                        // Wave 2 - mint
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave2FromTop,
                            baseHeight: 0.55,
                            amplitude: 45,
                            frequency: 1.2,
                            speed: 0.8 * speedMultiplier2,
                            color: Color(red: 0.1, green: 0.85, blue: 0.65)
                        )
                        
                        // Wave 3 - neon green
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave3FromTop,
                            baseHeight: 0.4,
                            amplitude: 40,
                            frequency: 1.4,
                            speed: 1.0 * speedMultiplier3,
                            color: Color(red: 0.2, green: 0.95, blue: 0.6)
                        )
                        
                    } else {
                        // Solid yellow base
                        Color(red: 1.0, green: 0.75, blue: 0.3)
                        
                        // Wave 1 - orange
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave1FromTop,
                            baseHeight: 0.7,
                            amplitude: 55,
                            frequency: 0.9,
                            speed: 0.55 * speedMultiplier1,
                            color: Color(red: 1.0, green: 0.55, blue: 0.3)
                        )
                        
                        // Wave 2 - coral/pink
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave2FromTop,
                            baseHeight: 0.6,
                            amplitude: 50,
                            frequency: 1.1,
                            speed: 0.75 * speedMultiplier2,
                            color: Color(red: 1.0, green: 0.45, blue: 0.4)
                        )
                        
                        // Wave 3 - hot pink
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave3FromTop,
                            baseHeight: 0.35,
                            amplitude: 45,
                            frequency: 1.3,
                            speed: 0.9 * speedMultiplier3,
                            color: Color(red: 1.0, green: 0.35, blue: 0.5)
                        )
                    }
                }
                .drawingGroup()
            }
        }
        .onAppear {
            // Randomize directions and speeds each time screen loads
            wave1FromTop = Bool.random()
            wave2FromTop = Bool.random()
            wave3FromTop = Bool.random()
            
            // Subtle speed variations (0.8 to 1.2, some negative for reverse flow)
            speedMultiplier1 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
            speedMultiplier2 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
            speedMultiplier3 = Double.random(in: 0.85...1.15) * (Bool.random() ? 1 : -1)
        }
        .ignoresSafeArea()
    }
}

// Simple horizontal fluid wave (top or bottom)
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
            HorizontalFluidShape(
                time: time,
                fromTop: fromTop,
                baseHeight: baseHeight,
                amplitude: amplitude,
                frequency: frequency,
                speed: speed
            )
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
            // Wave coming from top
            let waveY = rect.height * baseHeight
            
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            
            // Wavy bottom edge
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
            // Wave coming from bottom
            let waveY = rect.height * (1 - baseHeight)
            
            path.move(to: CGPoint(x: 0, y: rect.height))
            
            // Wavy top edge
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
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: AppSettings
    
    @State private var showImage = false
    @State private var showPickers = false
    @State private var showButton = false
    @State private var showStats = false
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: isLandscape ? 12 : 20) {
                Image("logo2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: isLandscape ? 35 : 45, height: isLandscape ? 35 : 45)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white, lineWidth: 3)
                    )
                    .offset(y: showImage ? 0 : UIScreen.main.bounds.height)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showImage)
                
                if !choicesMade {
                    HStack {
                        VStack(spacing: isLandscape ? 4 : 8) {
                            Text("Lock In Time")
                                .font(isLandscape ? .headline : .title).bold()
                            
                            Picker("Lock In Time", selection: $studyTime) {
                                ForEach(1...60, id: \.self) { num in
                                    Text("\(num) min").foregroundStyle(.white).bold()
                                }
                            }
                            .frame(maxWidth: 350, maxHeight: isLandscape ? 120 : nil)
                            .shadow(radius: 20)
                            .pickerStyle(.wheel)
                            .background(.ultraThinMaterial)
                            .cornerRadius(isLandscape ? 20 : 30)
                            .overlay(RoundedRectangle(cornerRadius: isLandscape ? 20 : 30).stroke(Color.white.opacity(0.5), lineWidth: 2))
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: isLandscape ? 4 : 8) {
                            Text("Chill Time")
                                .font(isLandscape ? .headline : .title).bold()
                            
                            Picker("Chill Time", selection: $restTime) {
                                ForEach(1...60, id: \.self) { num in
                                    Text("\(num) min").foregroundStyle(.white).bold()
                                }
                            }
                            .frame(maxWidth: 350, maxHeight: isLandscape ? 120 : nil)
                            .shadow(radius: 20)
                            .pickerStyle(.wheel)
                            .background(.ultraThinMaterial)
                            .cornerRadius(isLandscape ? 20 : 30)
                            .overlay(RoundedRectangle(cornerRadius: isLandscape ? 20 : 30).stroke(Color.white.opacity(0.5), lineWidth: 2))
                        }
                        .padding(.horizontal)
                    }
                    .offset(y: showPickers ? 0 : UIScreen.main.bounds.height)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showPickers)
                        
                        Button("Done") { choicesMade = true }
                            .frame(width: 75, height: 30)
                            .foregroundStyle(.white)
                            .background(.blue.opacity(0.7))
                            .clipShape(.capsule)
                            .shadow(radius: 20)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white, lineWidth: 3))
                            .offset(y: showButton ? 0 : UIScreen.main.bounds.height)
                            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2), value: showButton)
                        
                        // Stats Section
                        VStack(spacing: isLandscape ? 10 : 16) {
                            Button {
                                withAnimation(.spring(response: 0.4)) {
                                    showStats.toggle()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                    Text("Your Stats")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: showStats ? "chevron.up" : "chevron.down")
                                }
                                .foregroundColor(.white)
                                .padding(isLandscape ? 12 : 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                            
                            if showStats {
                                VStack(spacing: isLandscape ? 10 : 16) {
                                    HStack(spacing: 16) {
                                        PickerStatBox(title: "Today", value: stats.todayFormatted, icon: "sun.max.fill", color: .orange)
                                        PickerStatBox(title: "This Week", value: stats.weekFormatted, icon: "calendar", color: .blue)
                                    }
                                    
                                    HStack(spacing: 16) {
                                        PickerStatBox(title: "Sessions", value: "\(stats.sessionsCompleted)", icon: "checkmark.circle.fill", color: .green)
                                        PickerStatBox(title: "Streak", value: "\(stats.currentStreak) days", icon: "flame.fill", color: .red)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, isLandscape ? 10 : 20)
                        .offset(y: showButton ? 0 : UIScreen.main.bounds.height)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3), value: showButton)
                }
            }
            .padding(.vertical, isLandscape ? 20 : 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
        .background(AnimatedMeshBackground())
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showImage = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showPickers = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showButton = true }
        }
    }
}

struct PickerStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Timer Screen
struct TimerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @ObservedObject var settings: AppSettings
    @ObservedObject var stats: StatsManager
    @ObservedObject var soundManager: FocusSoundManager
    
    @State private var isStudy = true
    @State private var secondsLeft: Int
    @State private var timerRunning = false
    @State private var sessionComplete = false
    @State private var consecutiveSessions = 0
    @State private var isLongBreak = false
    @State private var studySecondsThisSession = 0
    
    // Background handling
    @State private var timerStartTime: Date?
    @State private var backgroundTime: Date?
    
    @State private var audioPlayer: AVAudioPlayer?
    
    // Camera/Timelapse
    @StateObject private var cameraManager = CameraManager()
    @State private var showCameraPreview = false
    @State private var timelapseMessage: String?
    @State private var showTimelapseAlert = false
    
    // Settings & Stats UI
    @State private var showSettings = false
    
    // Auto-hide gear button
    @State private var showGearButton = true
    @State private var hideTimer: Timer?
    
    // Motion manager for fluid effect
    @StateObject private var motionManager = MotionManager()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(studyTime: Binding<Int>, restTime: Binding<Int>, settings: AppSettings, stats: StatsManager, soundManager: FocusSoundManager) {
        self._studyTime = studyTime
        self._restTime = restTime
        self._settings = ObservedObject(wrappedValue: settings)
        self._stats = ObservedObject(wrappedValue: stats)
        self._soundManager = ObservedObject(wrappedValue: soundManager)
        self._secondsLeft = State(initialValue: studyTime.wrappedValue * 60)
    }
    
    var totalSeconds: Int {
        if isStudy {
            return studyTime * 60
        } else if isLongBreak {
            return settings.longBreakTime * 60
        } else {
            return restTime * 60
        }
    }
    
    var progress: CGFloat {
        CGFloat(totalSeconds - secondsLeft) / CGFloat(totalSeconds)
    }
    
    var studyGradient: LinearGradient {
        LinearGradient(colors: [settings.studyColor.opacity(0.7), settings.studyColor],
                      startPoint: .leading, endPoint: .trailing)
    }
    
    var restGradient: LinearGradient {
        LinearGradient(colors: [settings.restColor.opacity(0.7), settings.restColor],
                      startPoint: .leading, endPoint: .trailing)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                (isStudy ? settings.studyBackgroundColor : settings.restBackgroundColor)
                    .ignoresSafeArea()
                
                // Fluid progress fill
                FluidFillView(
                    progress: progress,
                    gradient: isStudy ? studyGradient : restGradient,
                    motionManager: motionManager
                )
                
                // Fixed centered content
                VStack(spacing: 30) {
                    // Timer label with session indicator
                    VStack(spacing: 8) {
                        Text(isStudy ? "Lock In Time" : (isLongBreak ? "Long Chill" : "Chill Time"))
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        if settings.longBreakEnabled {
                            Text("Session \(consecutiveSessions + 1) of \(settings.sessionsUntilLongBreak)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Text(timeString(from: secondsLeft))
                        .font(.system(size: 70, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                    
                    // Control buttons
                    HStack(spacing: 16) {
                        Button {
                            toggleTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                Text(timerRunning ? "Pause" : "Start").bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle(isActive: timerRunning, activeColor: .green))
                        
                        Button {
                            resetTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset").bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle())
                        
                        Button {
                            toggleTimelapse()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cameraManager.isRecording ? "video.fill" : "video")
                                Text(cameraManager.isRecording ? "Rec" : "Timelapse").bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle(isActive: cameraManager.isRecording, activeColor: .red))
                    }
                    
                    // Sound indicator
                    if soundManager.currentSound != nil && soundManager.isPlaying {
                        HStack(spacing: 6) {
                            Image(systemName: "speaker.wave.2.fill")
                            Text(soundManager.currentSound?.displayName ?? "")
                        }
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(.white.opacity(0.15)))
                    }
                }
                
                // Camera preview
                if showCameraPreview {
                    DraggableCameraPreview(cameraManager: cameraManager)
                }
                
                // Gear button (auto-hiding)
                if showGearButton {
                    VStack {
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.spring(response: 0.4)) { showSettings = true }
                                showGearButtonTemporarily()
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                            }
                            .padding(.trailing, 60)
                            .padding(.top, 8)
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
                
                // Settings panel
                if showSettings {
                    SettingsPanel(settings: settings, soundManager: soundManager, isPresented: $showSettings)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .onTapGesture {
            showGearButtonTemporarily()
        }
        .onAppear {
            showGearButtonTemporarily()
        }
        .onReceive(timer) { _ in
            guard timerRunning else { return }
            
            if secondsLeft > 0 {
                secondsLeft -= 1
                if isStudy {
                    studySecondsThisSession += 1
                }
            } else {
                timerCompleted()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            updateTimerFromBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if timerRunning { backgroundTime = Date() }
        }
        .alert("Timelapse", isPresented: $showTimelapseAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(timelapseMessage ?? "")
        }
        .onDisappear {
            cameraManager.cleanup()
            soundManager.stop()
        }
    }
    
    func showGearButtonTemporarily() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showGearButton = true
        }
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showGearButton = false
            }
        }
    }
    
    func toggleTimer() {
        timerRunning.toggle()
        
        if timerRunning {
            timerStartTime = Date()
            scheduleTimerEndNotification()
            
            // Start focus sound if study time
            if isStudy && soundManager.currentSound != nil {
                soundManager.play()
            }
        } else {
            cancelScheduledNotifications()
            timerStartTime = nil
            soundManager.pause()
        }
    }
    
    func resetTimer() {
        timerRunning = false
        isStudy = true
        isLongBreak = false
        secondsLeft = studyTime * 60
        timerStartTime = nil
        backgroundTime = nil
        sessionComplete = false
        studySecondsThisSession = 0
        cancelScheduledNotifications()
        soundManager.stop()
    }
    
    func timerCompleted() {
        if !settings.isMuted {
            playDingSound()
        }
        
        cancelScheduledNotifications()
        scheduleCompletionNotification()
        
        let wasStudy = isStudy
        
        if wasStudy {
            // Record study time
            stats.addStudyTime(seconds: studySecondsThisSession)
            studySecondsThisSession = 0
            consecutiveSessions += 1
            
            // Stop focus sound during break
            soundManager.pause()
            
            // Check if it's time for a long break
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
            // Break finished, start study
            isStudy = true
            isLongBreak = false
            secondsLeft = studyTime * 60
            
            // Resume focus sound
            if timerRunning && soundManager.currentSound != nil {
                soundManager.play()
            }
        }
        
        // Timelapse continues recording regardless of timer cycles
        // User must manually stop recording
        
        if timerRunning {
            timerStartTime = Date()
            scheduleTimerEndNotification()
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
            timelapseMessage = "Timelapse requires a real device. The camera is not available in the simulator."
            showTimelapseAlert = true
            return
        }
        
        if cameraManager.isRecording {
            cameraManager.onTimelapseComplete = { url in
                timelapseMessage = url != nil ? "Timelapse saved to your photo library!" : "Could not create timelapse. Try recording a longer session."
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
                            timelapseMessage = url != nil ? "Timelapse saved to your photo library!" : "Could not create timelapse. Try recording a longer session."
                            showTimelapseAlert = true
                        }
                    }
                } else {
                    timelapseMessage = "Camera access is required for timelapse. Please enable it in Settings."
                    showTimelapseAlert = true
                }
            }
        }
    }
    
    func updateTimerFromBackground() {
        guard let backgroundTime = backgroundTime, timerRunning else { return }
        
        let timeElapsed = Date().timeIntervalSince(backgroundTime)
        let secondsElapsed = Int(timeElapsed)
        
        if secondsElapsed >= secondsLeft {
            var remainingElapsed = secondsElapsed
            while remainingElapsed >= secondsLeft {
                remainingElapsed -= secondsLeft
                timerCompleted()
            }
            secondsLeft -= remainingElapsed
        } else {
            secondsLeft -= secondsElapsed
            if isStudy {
                studySecondsThisSession += secondsElapsed
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
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling notification: \(error)") }
        }
    }
    
    func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Lock In Time Done!" : "Chill Time Done!"
        content.body = isStudy ? "Time to rest!" : "Time to study!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_completed_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Error scheduling notification: \(error)") }
        }
    }
    
    func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["timer_end", "timer_completed"])
    }
    
    func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    func playDingSound() {
        // Try to play custom ding sound first
        if let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") {
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
                try audioSession.setActive(true)
                
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.volume = 1.0
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                return
            } catch {
                print("Error playing custom ding: \(error)")
            }
        }
        
        // Fallback to system sound
        AudioServicesPlaySystemSound(1007) // Default "received" sound
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var studyTime = 25
    @State private var restTime = 5
    @State private var choicesMade = false
    @State private var showLogoScreen = false
    @StateObject private var settings = AppSettings()
    @StateObject private var stats = StatsManager()
    @StateObject private var soundManager = FocusSoundManager()

    init() {
        let logoViewCount = UserDefaults.standard.integer(forKey: "logoViewCount")
        _showLogoScreen = State(initialValue: logoViewCount < 2)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if showLogoScreen {
                    LogoScreen(isFinished: $showLogoScreen)
                } else if !choicesMade {
                    PickerScreen(studyTime: $studyTime, restTime: $restTime, choicesMade: $choicesMade, stats: stats, settings: settings)
                } else {
                    TimerScreen(studyTime: $studyTime, restTime: $restTime, settings: settings, stats: stats, soundManager: soundManager)
                        .toolbar {
                            Button("", systemImage: "xmark") { choicesMade = false }
                        }
                }
            }
        }
        .onAppear {
            requestNotificationPermission()
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
