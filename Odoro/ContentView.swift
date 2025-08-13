//
//  ContentView.swift
//  Odoro
//
//  Created by Gunish Sharma on 2025-08-08.
//

import SwiftUI
internal import Combine


struct LogoScreen: View {
    @State private var isVisible = true
    var body: some View {
        ZStack {
            if isVisible {
                Color(red: 245/255, green: 245/255, blue: 245/255)
                    .ignoresSafeArea()
                VStack {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .onAppear {
                            // Hide after 3 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    isVisible = false
                                }
                            }
                        }
                        .transition(.opacity) // Fade-out animation
                    Text("Your study buddy")
                        .font(.headline).bold()
                        .foregroundStyle(.gray)
                }
            }
        }
    }
}

struct PickerScreen: View {
    @Binding var studyTime: Int
    @Binding var restTime: Int
    @Binding var choicesMade: Bool
    var body: some View {
        VStack {
            if !choicesMade {
                HStack {
                    
                    VStack {
                        Text("Study Time")
                        Picker("Study Time", selection: $studyTime) {
                            ForEach(1..<60, id: \.self) { num in
                                Text("\(num) min")
                            }
                        }
                    }
                    .pickerStyle(.wheel)
                    VStack {
                        Text("Rest Time")
                        Picker("Rest Time", selection: $restTime) {
                            ForEach(1..<60, id: \.self) { num in
                                Text("\(num) min")
                            }
                        }
                        .pickerStyle(.wheel)
                    }
                }
                Button("Choose") {
                    choicesMade = true
                }
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
    
    @State private var dragging = false
    
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
                Color.gray.opacity(0.3)
                    .ignoresSafeArea()

                
                (isStudy ? Color.purple : Color.orange)
//                    .frame(width: geo.size.width * progress)
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
                            timerRunning.toggle()
                        }
                        .font(.title2)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        
                        Button("Reset") {
                            resetTimer()
                        }
                        .font(.title2)
                        .padding()
                        .background(Color.white.opacity(0.3))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding()
            }
            .onReceive(timer) { _ in
                guard timerRunning else { return }
                
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    isStudy.toggle()
                    secondsLeft = (isStudy ? studyTime : restTime) * 60
                }
            }
        }
    }
    
    func resetTimer() {
        isStudy = true
        secondsLeft = studyTime * 60
        timerRunning = false
    }
    
    func timeString(from seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

struct ContentView: View {
    @State private var studyTime = 0
    @State private var restTime = 0
    @State private var choicesMade = false
    var body: some View {
        NavigationStack {
            ZStack {
                if !choicesMade {
                    PickerScreen(studyTime: $studyTime, restTime: $restTime, choicesMade: $choicesMade)
                }
                    LogoScreen()

                
                if choicesMade {
                    HStack {
                        TimerScreen(studyTime: $studyTime, restTime: $restTime)
                    }
                    .toolbar {
                        Button("", systemImage:"xmark") {
                            choicesMade = false
                        }
                        
                    }
                    
                }
                
            }
        }
    }
}

#Preview {
    ContentView()
}
