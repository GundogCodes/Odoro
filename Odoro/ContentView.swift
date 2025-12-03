//
//  ContentView.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI
internal import Combine
import AVFoundation
import UserNotifications
import Photos

// MARK: - App Settings
class AppSettings: ObservableObject {
    @Published var studyColor: Color {
        didSet { saveColor(studyColor, key: "studyColor") }
    }
    @Published var restColor: Color {
        didSet { saveColor(restColor, key: "restColor") }
    }
    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "isMuted") }
    }
    
    init() {
        self.studyColor = Self.loadColor(key: "studyColor") ?? .purple
        self.restColor = Self.loadColor(key: "restColor") ?? .red
        self.isMuted = UserDefaults.standard.bool(forKey: "isMuted")
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
    private var photoOutput: AVCapturePhotoOutput?
    private var captureTimer: Timer?
    private let captureInterval: TimeInterval = 3.0 // Capture every 3 seconds
    
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
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("Failed to access front camera")
            return
        }
        
        if captureSession?.canAddInput(input) == true {
            captureSession?.addInput(input)
        }
        
        photoOutput = AVCapturePhotoOutput()
        if let photoOutput = photoOutput, captureSession?.canAddOutput(photoOutput) == true {
            captureSession?.addOutput(photoOutput)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func startRecording() {
        guard !isRecording else { return }
        
        isRecording = true
        capturedFrames.removeAll()
        
        // Capture first frame immediately
        captureFrame()
        
        // Start periodic capture
        captureTimer = Timer.scheduledTimer(withTimeInterval: captureInterval, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        isRecording = false
        captureTimer?.invalidate()
        captureTimer = nil
        
        // Create timelapse video
        if capturedFrames.count > 1 {
            createTimelapseVideo()
        } else {
            onTimelapseComplete?(nil)
        }
    }
    
    private func captureFrame() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    private func createTimelapseVideo() {
        guard !capturedFrames.isEmpty else {
            onTimelapseComplete?(nil)
            return
        }
        
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("timelapse_\(Date().timeIntervalSince1970).mp4")
        
        // Delete existing file if needed
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let firstImage = capturedFrames.first else {
            onTimelapseComplete?(nil)
            return
        }
        
        let size = firstImage.size
        
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            onTimelapseComplete?(nil)
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
        
        let frameDuration = CMTime(value: 1, timescale: 8) // 8 fps for timelapse
        var frameCount: Int64 = 0
        
        let queue = DispatchQueue(label: "videoWriterQueue")
        
        writerInput.requestMediaDataWhenReady(on: queue) { [weak self] in
            guard let self = self else { return }
            
            while writerInput.isReadyForMoreMediaData && Int(frameCount) < self.capturedFrames.count {
                let image = self.capturedFrames[Int(frameCount)]
                if let buffer = self.pixelBuffer(from: image) {
                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                    adaptor.append(buffer, withPresentationTime: presentationTime)
                }
                frameCount += 1
            }
            
            if Int(frameCount) >= self.capturedFrames.count {
                writerInput.markAsFinished()
                writer.finishWriting {
                    DispatchQueue.main.async {
                        if writer.status == .completed {
                            self.saveToPhotoLibrary(url: outputURL)
                        } else {
                            self.onTimelapseComplete?(nil)
                        }
                    }
                }
            }
        }
    }
    
    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        let size = image.size
        var pixelBuffer: CVPixelBuffer?
        
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )
        
        guard let buffer = pixelBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
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
                DispatchQueue.main.async {
                    self.onTimelapseComplete?(nil)
                }
                return
            }
            
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } completionHandler: { success, error in
                DispatchQueue.main.async {
                    self.onTimelapseComplete?(success ? url : nil)
                }
            }
        }
    }
    
    func cleanup() {
        captureSession?.stopRunning()
        captureTimer?.invalidate()
    }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        
        DispatchQueue.main.async {
            self.previewImage = image
            if self.isRecording {
                self.capturedFrames.append(image)
            }
        }
    }
}

// MARK: - Draggable Camera Preview
struct DraggableCameraPreview: View {
    @ObservedObject var cameraManager: CameraManager
    @State private var position: CGPoint = CGPoint(x: 80, y: 120)
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Liquid glass background
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                // Camera preview
                if let image = cameraManager.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .scaleX(-1) // Mirror for front camera
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.black.opacity(0.3))
                        .frame(width: 100, height: 130)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.title2)
                        )
                }
                
                // Recording indicator
                if cameraManager.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        Text("\(cameraManager.capturedFrames.count)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.5))
                    )
                }
            }
            .padding(10)
        }
        .frame(width: 120, height: cameraManager.isRecording ? 190 : 160)
        .position(
            x: position.x + dragOffset.width,
            y: position.y + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    position.x += value.translation.width
                    position.y += value.translation.height
                    dragOffset = .zero
                }
        )
    }
}

extension View {
    func scaleX(_ scale: CGFloat) -> some View {
        self.scaleEffect(x: scale, y: 1)
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
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                    
                    if isActive {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(activeColor.opacity(0.3))
                    }
                    
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
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
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.4)) {
                        isPresented = false
                    }
                }
            
            // Settings card
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("Settings")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Divider()
                    .background(.white.opacity(0.3))
                
                // Study Color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Study Timer Color")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ColorPicker("", selection: $settings.studyColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
                
                // Rest Color
                VStack(alignment: .leading, spacing: 12) {
                    Text("Break Timer Color")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    ColorPicker("", selection: $settings.restColor, supportsOpacity: false)
                        .labelsHidden()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 8)
                }
                
                Divider()
                    .background(.white.opacity(0.3))
                
                // Mute Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mute Sound")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Silence the ding notification")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.isMuted)
                        .labelsHidden()
                        .tint(.orange)
                }
                
                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 340, maxHeight: 400)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: 28)
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .blue.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
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
                        .frame(minWidth: 90, maxWidth:120 )
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
                .padding(.top ,100)

                Text("Your study buddy")
                    .padding(.top, 100)
                    .font(.headline).bold()
                    .foregroundStyle(.regularMaterial)
            }
        }
    }
}

// MARK: - Picker Screen
struct PickerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @Binding var choicesMade: Bool
    
    @State private var showImage = false
    @State private var showPickers = false
    @State private var showButton = false
    
    var body: some View {
        VStack {
            Image("logo2")
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white, lineWidth: 3)
                )
                .offset(y: showImage ? 0 : UIScreen.main.bounds.height)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showImage)
            
            if !choicesMade {
                HStack {
                    VStack {
                        Text("Study Time")
                            .font(.title).bold()
                        
                        Picker("Study Time", selection: $studyTime) {
                            ForEach(1...60, id: \.self) { num in
                                Text("\(num) min")
                                    .foregroundStyle(.white).bold()
                            }
                        }
                        .frame(maxWidth: 350)
                        .shadow(radius: 20)
                        .pickerStyle(.wheel)
                        .background(.purple.opacity(0.7))
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white, lineWidth: 3)
                        )
                    }
                    .padding(.horizontal)
                    
                    VStack {
                        Text("Rest Time")
                            .font(.title).bold()
                        
                        Picker("Rest Time", selection: $restTime) {
                            ForEach(1...60, id: \.self) { num in
                                Text("\(num) min")
                                    .foregroundStyle(.white).bold()
                            }
                        }
                        .frame(maxWidth: 350)
                        .shadow(radius: 20)
                        .pickerStyle(.wheel)
                        .background(.orange.opacity(0.7))
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white, lineWidth: 3)
                        )
                    }
                    .padding(.horizontal)
                }
                .offset(y: showPickers ? 0 : UIScreen.main.bounds.height)
                .animation(.spring(response: 0.6, dampingFraction: 0.75), value: showPickers)
                
                Button("Done") {
                    choicesMade = true
                }
                .frame(width: 75, height: 30)
                .foregroundStyle(.white)
                .background(.blue.opacity(0.7))
                .clipShape(.capsule)
                .shadow(radius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white, lineWidth: 3)
                )
                .offset(y: showButton ? 0 : UIScreen.main.bounds.height)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2), value: showButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white)
        .background(
            LinearGradient(colors: [.pink.opacity(0.4), .pink.opacity(0.7)],
                           startPoint: .top,
                           endPoint: .bottom)
        )
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showImage = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showPickers = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showButton = true
            }
        }
    }
}

// MARK: - Timer Screen
struct TimerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @ObservedObject var settings: AppSettings
    
    @State private var isStudy = true
    @State private var secondsLeft: Int
    @State private var timerRunning = false
    @State private var sessionComplete = false // Tracks work+break cycle
    
    // Background handling
    @State private var timerStartTime: Date?
    @State private var backgroundTime: Date?
    
    @State private var dragging = false
    @State private var audioPlayer: AVAudioPlayer?
    
    // Camera/Timelapse
    @StateObject private var cameraManager = CameraManager()
    @State private var showCameraPreview = false
    @State private var timelapseMessage: String?
    @State private var showTimelapseAlert = false
    
    // Settings
    @State private var showSettings = false
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(studyTime: Binding<Int>, restTime: Binding<Int>, settings: AppSettings) {
        self._studyTime = studyTime
        self._restTime = restTime
        self._settings = ObservedObject(wrappedValue: settings)
        self._secondsLeft = State(initialValue: studyTime.wrappedValue * 60)
    }
    
    var totalSeconds: Int {
        isStudy ? studyTime * 60 : restTime * 60
    }
    
    var progress: CGFloat {
        CGFloat(totalSeconds - secondsLeft) / CGFloat(totalSeconds)
    }
    
    var studyGradient: LinearGradient {
        LinearGradient(
            colors: [settings.studyColor.opacity(0.7), settings.studyColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var restGradient: LinearGradient {
        LinearGradient(
            colors: [settings.restColor.opacity(0.7), settings.restColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background
                (isStudy ? Color.green.opacity(0.3) : Color.orange.opacity(0.7))
                    .ignoresSafeArea()
                
                // Progress fill
                (isStudy ? studyGradient : restGradient)
                    .frame(width: UIScreen.main.bounds.width * progress)
                    .ignoresSafeArea()
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragging = true
                                let geoWidth = geo.size.width
                                let locationX = min(max(value.location.x, 0), geoWidth)
                                let invertedX = geoWidth - locationX
                                let newProgress = invertedX / geoWidth
                                
                                let newSeconds = Int(newProgress * CGFloat(totalSeconds))
                                let clampedSeconds = max(isStudy ? studyTime : restTime, newSeconds)
                                let newMinutes = max(isStudy ? studyTime : restTime, Int(ceil(Double(clampedSeconds) / 60.0)))
                                
                                if isStudy {
                                    studyTime = newMinutes
                                    secondsLeft = clampedSeconds
                                } else {
                                    restTime = newMinutes
                                    secondsLeft = clampedSeconds
                                }
                            }
                            .onEnded { _ in
                                dragging = false
                            }
                    )
                
                // Main content
                VStack(spacing: 40) {
                    Text(isStudy ? "Study Time" : "Rest Time")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(timeString(from: secondsLeft))
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .frame(minWidth: 200)
                        .foregroundColor(.white)
                    
                    // Control buttons
                    HStack(spacing: 20) {
                        Button {
                            toggleTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: timerRunning ? "pause.fill" : "play.fill")
                                Text(timerRunning ? "Pause" : "Start")
                                    .bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle(isActive: timerRunning, activeColor: .green))
                        
                        Button {
                            resetTimer()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset")
                                    .bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                    
                    // Timelapse button
                    HStack(spacing: 20) {
                        Button {
                            toggleTimelapse()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: cameraManager.isRecording ? "video.fill" : "video")
                                Text(cameraManager.isRecording ? "Recording..." : "Timelapse")
                                    .bold()
                            }
                            .foregroundColor(.white)
                        }
                        .buttonStyle(GlassButtonStyle(isActive: cameraManager.isRecording, activeColor: .red))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
                
                // Camera preview overlay (draggable)
                if showCameraPreview {
                    DraggableCameraPreview(cameraManager: cameraManager)
                }
                
                // Settings button (top right)
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.4)) {
                                showSettings = true
                            }
                        } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            Circle()
                                                .stroke(.white.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
                        }
                        .padding(.trailing, 60) // Account for toolbar X button
                        .padding(.top, 8)
                    }
                    Spacer()
                }
                
                // Settings panel overlay
                if showSettings {
                    SettingsPanel(settings: settings, isPresented: $showSettings)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
        }
        .onReceive(timer) { _ in
            guard timerRunning else { return }
            
            if secondsLeft > 0 {
                secondsLeft -= 1
            } else {
                timerCompleted()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            updateTimerFromBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            if timerRunning {
                backgroundTime = Date()
            }
        }
        .alert("Timelapse", isPresented: $showTimelapseAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(timelapseMessage ?? "")
        }
        .onDisappear {
            cameraManager.cleanup()
        }
    }
    
    func toggleTimer() {
        timerRunning.toggle()
        
        if timerRunning {
            timerStartTime = Date()
            scheduleTimerEndNotification()
        } else {
            cancelScheduledNotifications()
            timerStartTime = nil
        }
    }
    
    func resetTimer() {
        timerRunning = false
        isStudy = true
        secondsLeft = studyTime * 60
        timerStartTime = nil
        backgroundTime = nil
        sessionComplete = false
        cancelScheduledNotifications()
    }
    
    func timerCompleted() {
        // Play sound if not muted
        if !settings.isMuted {
            playDingSound()
        }
        
        cancelScheduledNotifications()
        scheduleCompletionNotification()
        
        // Check if we're completing a break (end of work+break cycle)
        let wasStudy = isStudy
        
        // Switch modes
        isStudy.toggle()
        secondsLeft = (isStudy ? studyTime : restTime) * 60
        
        // If we just finished a break, that's a complete session
        if !wasStudy {
            sessionComplete = true
            
            // Stop timelapse after work+break cycle
            if cameraManager.isRecording {
                cameraManager.stopRecording()
                showCameraPreview = false
            }
        }
        
        // Keep timer running for next phase and schedule new notification
        if timerRunning {
            timerStartTime = Date()
            scheduleTimerEndNotification()
        }
    }
    
    func toggleTimelapse() {
        if cameraManager.isRecording {
            // Stop recording
            cameraManager.onTimelapseComplete = { url in
                if url != nil {
                    timelapseMessage = "Timelapse saved to your photo library!"
                } else {
                    timelapseMessage = "Could not create timelapse. Try recording a longer session."
                }
                showTimelapseAlert = true
            }
            cameraManager.stopRecording()
            showCameraPreview = false
        } else {
            // Request permission and start
            cameraManager.requestPermission { granted in
                if granted {
                    cameraManager.setupCamera()
                    
                    // Wait for camera to initialize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCameraPreview = true
                        cameraManager.startRecording()
                        
                        // Set up completion handler
                        cameraManager.onTimelapseComplete = { url in
                            if url != nil {
                                timelapseMessage = "Timelapse saved to your photo library!"
                            } else {
                                timelapseMessage = "Could not create timelapse. Try recording a longer session."
                            }
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
        }
        
        self.backgroundTime = nil
    }
    
    func scheduleTimerEndNotification() {
        cancelScheduledNotifications()
        
        guard secondsLeft > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Study Time Complete!" : "Break Time Complete!"
        content.body = isStudy ? "Time for a break!" : "Time to study!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secondsLeft), repeats: false)
        let request = UNNotificationRequest(identifier: "timer_end", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling timer end notification: \(error)")
            }
        }
    }
    
    func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Study Timer Done!" : "Break Timer Done!"
        content.body = isStudy ? "Time to rest!" : "Time to study!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_completed_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling completion notification: \(error)")
            }
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
        guard let url = Bundle.main.url(forResource: "ding", withExtension: "mp3") else {
            print("Ding sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error playing ding sound: \(error.localizedDescription)")
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @State private var studyTime = 25
    @State private var restTime = 5
    @State private var choicesMade = false
    @State private var showLogoScreen = false
    @StateObject private var settings = AppSettings()

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
                    PickerScreen(studyTime: $studyTime, restTime: $restTime, choicesMade: $choicesMade)
                } else {
                    TimerScreen(studyTime: $studyTime, restTime: $restTime, settings: settings)
                        .toolbar {
                            Button("", systemImage:"xmark") { choicesMade = false }
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
            if granted {
                print("Notifications allowed")
            } else if let error = error {
                print("Error requesting notifications: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    ContentView()
}
