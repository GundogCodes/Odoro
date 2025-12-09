import SwiftUI

// MARK: - Tracker Home Screen
struct TrackerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showTimer: Bool
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ZStack {
            // Animated wave background
            AnimatedMeshBackground()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with logo and title - left aligned
                    HStack(spacing: 10) {
                        if colorScheme == .light {
                            Image("logo2")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            
                            Text("Tracker")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        } else if colorScheme == .dark {
                            Image("logo3")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            
                            Text("Tracker")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            
                        }
                        
                        
                        
                    }
                    .padding(.top, 60)
                    
                    // Lock In Now button - left aligned text, clear background
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
                    
                    // Today's stats card
                    TodayStatsCard(stats: stats)
                    
                    // Habits section
                    HabitsPlaceholderCard()
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Today's Stats Card
struct TodayStatsCard: View {
    @ObservedObject var stats: StatsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("Today's Focus")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatItem(
                    icon: "clock.fill",
                    value: stats.todayFormatted,
                    label: "Focus Time"
                )
                
                StatItem(
                    icon: "checkmark.circle.fill",
                    value: "\(stats.sessionsCompleted)",
                    label: "Sessions"
                )
                
                StatItem(
                    icon: "flame.fill",
                    value: "\(stats.currentStreak)",
                    label: "Day Streak"
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
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
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Habits Placeholder Card
struct HabitsPlaceholderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "list.bullet.clipboard.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Habits")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                
                Button {
                    // Add habit action - to be implemented
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Placeholder content
            VStack(spacing: 12) {
                HabitRowPlaceholder(name: "Morning Meditation", icon: "brain.head.profile", color: .purple, completed: true)
                HabitRowPlaceholder(name: "Read 30 minutes", icon: "book.fill", color: .green, completed: false)
                HabitRowPlaceholder(name: "Exercise", icon: "figure.run", color: .orange, completed: false)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Habit Row Placeholder
struct HabitRowPlaceholder: View {
    let name: String
    let icon: String
    let color: Color
    let completed: Bool
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(name)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(completed ? .green : .white.opacity(0.4))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.white.opacity(completed ? 0.1 : 0.05))
        )
    }
}

#Preview {
    TrackerView(showTimer: .constant(false), stats: StatsManager(), settings: AppSettings())
}
