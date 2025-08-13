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
                            // jump up animation
                            jumpUp = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { jumpUp = false }
                            
                            // Wait 1 second before finishing logo
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                // update binding outside animation
                                isFinished = false  // Changed to false to hide logo screen
                                
                                // Increment logo view count
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

struct PickerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @Binding var choicesMade: Bool
    
    @State private var showImage = false
    @State private var showPickers = false
    @State private var showButton = false
    
    var body: some View {
        VStack {
            // Logo Image
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
                // Pickers section
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
                
                // Done button
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
            // Animate all elements sequentially
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

struct TimerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    
    @State private var isStudy = true
    @State private var secondsLeft: Int
    @State private var timerRunning = false
    
    // Background handling
    @State private var timerStartTime: Date?
    @State private var backgroundTime: Date?
    
    @State private var dragging = false
    @State private var audioPlayer: AVAudioPlayer?
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init(studyTime: Binding<Int>, restTime: Binding<Int>) {
        self._studyTime = studyTime
        self._restTime = restTime
        // Initialize secondsLeft to studyTime * 60 initially
        self._secondsLeft = State(initialValue: studyTime.wrappedValue * 60)
    }
    
    var totalSeconds: Int {
        isStudy ? studyTime * 60 : restTime * 60
    }
    
    var progress: CGFloat {
        CGFloat(totalSeconds - secondsLeft) / CGFloat(totalSeconds)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                isStudy ?
                Color.green.opacity(0.3)
                    .ignoresSafeArea()
                :
                Color.orange.opacity(0.7)
                    .ignoresSafeArea()
                
                (isStudy ? LinearGradient(colors: [Color.purple.opacity(0.7), Color.purple.opacity(1)], startPoint: .leading, endPoint: .trailing)
                 : LinearGradient(colors: [Color.red.opacity(0.7),Color.red.opacity(1)], startPoint: .leading, endPoint: .trailing))
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
                            let clampedSeconds = max( isStudy ? studyTime : restTime, newSeconds)
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
            }
            VStack(spacing: 40) {
                VStack(spacing: 40) {
                    Text(isStudy ? "Study Time" : "Rest Time")
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)
                    
                    Text(timeString(from: secondsLeft))
                        .font(.system(size: 80, weight: .bold, design: .monospaced))
                        .frame(minWidth: 200)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 40) {
                        Button(timerRunning ? "Pause" : "Start") {
                            toggleTimer()
                        }
                        .font(.title2).bold()
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white, lineWidth: 3)
                        )
                        
                        Button("Reset") {
                            resetTimer()
                        }
                        .font(.title2).bold()
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.white, lineWidth: 3)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
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
        cancelScheduledNotifications()
    }
    
    func timerCompleted() {
        playDingSound()
        
        // Cancel the timer end notification since timer completed
        cancelScheduledNotifications()
        
        // Send immediate completion notification
        scheduleCompletionNotification()
        
        // Switch modes
        isStudy.toggle()
        secondsLeft = (isStudy ? studyTime : restTime) * 60
        
        // Keep timer running for next phase and schedule new notification
        if timerRunning {
            timerStartTime = Date()
            scheduleTimerEndNotification()
        }
    }
    
    func updateTimerFromBackground() {
        guard let backgroundTime = backgroundTime, timerRunning else { return }
        
        let timeElapsed = Date().timeIntervalSince(backgroundTime)
        let secondsElapsed = Int(timeElapsed)
        
        if secondsElapsed >= secondsLeft {
            // Timer should have completed (possibly multiple times)
            var remainingElapsed = secondsElapsed
            
            while remainingElapsed >= secondsLeft {
                remainingElapsed -= secondsLeft
                timerCompleted()
            }
            
            // Handle any remaining time
            secondsLeft -= remainingElapsed
        } else {
            // Update remaining time
            secondsLeft -= secondsElapsed
        }
        
        self.backgroundTime = nil
    }
    
    func scheduleTimerEndNotification() {
        // Cancel any existing notifications
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
            } else {
                print("✅ Scheduled notification for \(secondsLeft) seconds")
            }
        }
    }
    
    func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = isStudy ? "Study Timer Done!"  : "Break Timer Done!"
        content.body = isStudy ? "Time to rest!" : "Time to study!"
        content.sound = .default
        
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "timer_completed_\(UUID().uuidString)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling completion notification: \(error)")
            } else {
                print("✅ Scheduled completion notification")
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

struct ContentView: View {
    @State private var studyTime = 25
    @State private var restTime = 5
    @State private var choicesMade = false
    @State private var showLogoScreen = false

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
                    TimerScreen(studyTime: $studyTime, restTime: $restTime)
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
