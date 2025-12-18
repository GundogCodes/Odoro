import SwiftUI
internal import Combine

// MARK: - Tracker Background
struct TrackerBackground: View {
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
                        Color(red: 0.12, green: 0.10, blue: 0.25)
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave1FromTop,
                            baseHeight: 0.7,
                            amplitude: 45,
                            frequency: 0.8,
                            speed: 0.5 * speedMultiplier1,
                            color: Color(red: 0.25, green: 0.20, blue: 0.5)
                        )
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave2FromTop,
                            baseHeight: 0.55,
                            amplitude: 40,
                            frequency: 1.0,
                            speed: 0.65 * speedMultiplier2,
                            color: Color(red: 0.4, green: 0.25, blue: 0.65)
                        )
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave3FromTop,
                            baseHeight: 0.35,
                            amplitude: 35,
                            frequency: 1.2,
                            speed: 0.8 * speedMultiplier3,
                            color: Color(red: 0.55, green: 0.3, blue: 0.75)
                        )
                        
                    } else {
                        Color(red: 0.6, green: 0.7, blue: 0.9)
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave1FromTop,
                            baseHeight: 0.7,
                            amplitude: 50,
                            frequency: 0.85,
                            speed: 0.5 * speedMultiplier1,
                            color: Color(red: 0.4, green: 0.55, blue: 0.85)
                        )
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave2FromTop,
                            baseHeight: 0.55,
                            amplitude: 45,
                            frequency: 1.05,
                            speed: 0.65 * speedMultiplier2,
                            color: Color(red: 0.5, green: 0.45, blue: 0.8)
                        )
                        
                        HorizontalFluidWave(
                            time: time,
                            fromTop: wave3FromTop,
                            baseHeight: 0.35,
                            amplitude: 40,
                            frequency: 1.25,
                            speed: 0.8 * speedMultiplier3,
                            color: Color(red: 0.6, green: 0.4, blue: 0.75)
                        )
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

// MARK: - Orientation Manager
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    @Published var isLocked = false
    
    func lockToPortrait() {
        guard !isLocked else { return }
        isLocked = true
        forceOrientationUpdate()
    }
    
    func unlock() {
        guard isLocked else { return }
        isLocked = false
        forceOrientationUpdate()
    }
    
    private func forceOrientationUpdate() {
        DispatchQueue.main.async {
            if #available(iOS 16.0, *) {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
                let orientations: UIInterfaceOrientationMask = self.isLocked ? .portrait : .all
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in }
            }
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }
}

// MARK: - App Delegate for Orientation Control
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.isLocked ? .portrait : .all
    }
}

// MARK: - Tracker Home Screen
struct TrackerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showTimer: Bool
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: AppSettings
    
    private var orientationManager: OrientationManager { OrientationManager.shared }
    
    @State private var showHeader = false
    @State private var showLockInButton = false
    @State private var showStatsCard = false
    
    var body: some View {
        ZStack {
            TrackerBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with logo and title
                    HStack(spacing: 10) {
                        if colorScheme == .light {
                            Image("logo4")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        } else {
                            Image("logo5")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                        }
                        
                        Text("Tracker")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    }
                    .padding(.top, 60)
                    .opacity(showHeader ? 1 : 0)
                    .offset(y: showHeader ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showHeader)
                    
                    // Lock In Now button
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            showTimer = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "flame.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            Text("Lock In Now")
                                .font(.title3.bold())
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.body.weight(.semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.horizontal, 18)
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
                    .opacity(showLockInButton ? 1 : 0)
                    .offset(y: showLockInButton ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: showLockInButton)
                    
                    // Stats Card
                    StatsCard(stats: stats)
                        .opacity(showStatsCard ? 1 : 0)
                        .offset(y: showStatsCard ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: showStatsCard)
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.width < -50 && abs(value.translation.height) < 100 {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showTimer = true
                        }
                    }
                }
        )
        .onAppear {
            orientationManager.lockToPortrait()
            
            showHeader = false
            showLockInButton = false
            showStatsCard = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showHeader = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showLockInButton = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showStatsCard = true }
        }
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    @ObservedObject var stats: StatsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                Text("Your Stats")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            
            // Stats grid - 2 rows of 3
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    StatItem(icon: "sun.max.fill", value: stats.todayFormatted, label: "Today", color: .orange)
                    StatItem(icon: "calendar", value: stats.weekFormatted, label: "This Week", color: .blue)
                    StatItem(icon: "trophy.fill", value: stats.allTimeFormatted, label: "All Time", color: .yellow)
                }
                
                HStack(spacing: 12) {
                    StatItem(icon: "checkmark.circle.fill", value: "\(stats.sessionsCompleted)", label: "Sessions", color: .green)
                    StatItem(icon: "flame.fill", value: "\(stats.currentStreak)", label: "Day Streak", color: .red)
                    StatItem(icon: "chart.line.uptrend.xyaxis", value: stats.weeklyAverageFormatted, label: "Daily Avg", color: .purple)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    var color: Color = .orange
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    TrackerView(showTimer: .constant(false), stats: StatsManager(), settings: AppSettings())
}
