import SwiftUI
internal import Combine
import UserNotifications

// MARK: - Habit Model
enum HabitType: String, Codable, CaseIterable {
    case countdown = "Countdown"      // Counting down to a date
    case countUp = "Count Up"         // Counting up from a date
}

enum HabitUpdateMode: String, Codable, CaseIterable {
    case auto = "Auto Track"          // Automatically tracks time
    case manual = "Manual"            // User manually updates progress
}

enum HabitVisualStyle: String, Codable, CaseIterable {
    case grid = "Progress Grid"       // Grid that fills up
    case bar = "Timeline Bar"         // Filling bar
    case text = "Text Counter"        // Day/week/hr/sec text
}

enum HabitTimeUnit: String, Codable, CaseIterable {
    case seconds = "Seconds"
    case minutes = "Minutes"
    case hours = "Hours"
    case days = "Days"
    case weeks = "Weeks"
    case months = "Months"
    case years = "Years"
}

// What each tick on the timeline represents
enum TimelineTickUnit: String, Codable, CaseIterable {
    case minute = "Minutes"
    case hour = "Hours"
    case day = "Days"
    case week = "Weeks"
    case month = "Months"
    case year = "Years"
    
    var displayName: String { rawValue }
    
    var singularName: String {
        switch self {
        case .minute: return "minute"
        case .hour: return "hour"
        case .day: return "day"
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }
}

enum HabitWidgetSize: String, Codable, CaseIterable {
    case half = "Small"           // Square 4x4 to 7x7
    case fullMedium = "Medium"    // Full width, same height as small
    case full = "Large"           // Full width, taller
    
    var displayName: String { rawValue }
}

// What each cell in the grid represents
enum CellUnit: String, Codable, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var displayName: String { rawValue }
    
    var pluralName: String {
        switch self {
        case .day: return "days"
        case .week: return "weeks"
        case .month: return "months"
        case .year: return "years"
        }
    }
}

// How the grid duration is defined
enum GridDurationType: String, Codable, CaseIterable {
    case customRange = "Custom Range"
    case toTargetDate = "To Target Date"
    case indefinite = "Indefinite"
    
    var displayName: String {
        switch self {
        case .customRange: return "Custom Range"
        case .toTargetDate: return "To Target Date"
        case .indefinite: return "Indefinite (Cycles)"
        }
    }
}

// Duration types available for timeline bar (no indefinite)
enum BarDurationType: String, Codable, CaseIterable {
    case customRange = "Custom Range"
    case toTargetDate = "To Target Date"
    
    var displayName: String {
        switch self {
        case .customRange: return "Custom Range"
        case .toTargetDate: return "To Target Date"
        }
    }
    
    var toGridDurationType: GridDurationType {
        switch self {
        case .customRange: return .customRange
        case .toTargetDate: return .toTargetDate
        }
    }
}

// MARK: - Habit Note
struct HabitNote: Identifiable, Codable {
    var id = UUID()
    var content: String
    var createdAt: Date
    
    init(content: String) {
        self.content = content
        self.createdAt = Date()
    }
}

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String                    // SF Symbol name
    var type: HabitType
    var updateMode: HabitUpdateMode
    var visualStyle: HabitVisualStyle
    var widgetSize: HabitWidgetSize
    
    // Grid settings
    var cellUnit: CellUnit              // What each cell represents (day/month)
    var durationType: GridDurationType  // How duration is calculated
    var customDuration: Int             // Number of days/months for customRange
    var targetDate: Date?               // For countdown or toTargetDate duration
    var textCounterDuration: Int        // Duration value for text counter style
    var timelineTickUnit: TimelineTickUnit  // What each tick represents on timeline
    var timelineDuration: Int           // Duration value for timeline bar
    
    // Progress tracking
    var currentValue: Int               // Current progress (cells filled for manual)
    var cycleCount: Int                 // How many times grid has cycled (for indefinite)
    var manuallyFilledCells: Set<Int>   // Which specific cells are filled (for manual tracking)
    var lastResetDate: Date?            // For auto-tracking: when progress was last reset
    
    // Notes & Completion
    var notes: [HabitNote]              // User's timestamped notes/journal entries
    var isCompleted: Bool               // Whether the habit goal is completed
    var completedAt: Date?              // When the habit was marked complete
    var goalNotificationSent: Bool      // Whether goal reached notification was sent
    
    // Display settings
    var timeUnit: HabitTimeUnit         // Display unit for text counter
    var color: HabitColor
    
    var createdAt: Date
    
    // Start date is always creation date (today when created)
    var startDate: Date { createdAt }
    
    init(
        name: String,
        icon: String = "target",
        type: HabitType = .countUp,
        updateMode: HabitUpdateMode = .auto,
        visualStyle: HabitVisualStyle = .grid,
        widgetSize: HabitWidgetSize = .full,
        cellUnit: CellUnit = .day,
        durationType: GridDurationType = .customRange,
        customDuration: Int = 30,
        targetDate: Date? = nil,
        textCounterDuration: Int = 30,
        timelineTickUnit: TimelineTickUnit = .day,
        timelineDuration: Int = 30,
        timeUnit: HabitTimeUnit = .days,
        color: HabitColor = .blue
    ) {
        self.name = name
        self.icon = icon
        self.type = type
        self.updateMode = updateMode
        self.visualStyle = visualStyle
        self.widgetSize = widgetSize
        self.cellUnit = cellUnit
        self.durationType = durationType
        self.customDuration = customDuration
        self.targetDate = targetDate
        self.textCounterDuration = textCounterDuration
        self.timelineTickUnit = timelineTickUnit
        self.timelineDuration = timelineDuration
        self.currentValue = 0
        self.cycleCount = 0
        self.manuallyFilledCells = []
        self.notes = []
        self.isCompleted = false
        self.completedAt = nil
        self.goalNotificationSent = false
        self.timeUnit = timeUnit
        self.color = color
        self.createdAt = Date()
    }
    
    // Calculate current cell index based on elapsed time
    var currentCellIndex: Int {
        let calendar = Calendar.current
        let now = Date()
        
        switch cellUnit {
        case .day:
            return max(0, calendar.dateComponents([.day], from: startDate, to: now).day ?? 0)
        case .week:
            let days = calendar.dateComponents([.day], from: startDate, to: now).day ?? 0
            return max(0, days / 7)
        case .month:
            return max(0, calendar.dateComponents([.month], from: startDate, to: now).month ?? 0)
        case .year:
            return max(0, calendar.dateComponents([.year], from: startDate, to: now).year ?? 0)
        }
    }
    
    // Maximum cells each size can display
    var maxCellCapacity: Int {
        switch widgetSize {
        case .half: return 49         // 7x7
        case .fullMedium: return 105  // 15x7
        case .full: return 210        // 15x14
        }
    }
    
    // Total duration in cell units (actual full duration, not capped)
    var totalDurationCells: Int {
        switch durationType {
        case .customRange:
            return max(4, customDuration)
        case .toTargetDate:
            guard let target = targetDate else { return max(4, customDuration) }
            let calendar = Calendar.current
            switch cellUnit {
            case .day:
                return max(4, calendar.dateComponents([.day], from: startDate, to: target).day ?? 0)
            case .week:
                let days = calendar.dateComponents([.day], from: startDate, to: target).day ?? 0
                return max(4, Int(ceil(Double(days) / 7.0)))
            case .month:
                return max(4, calendar.dateComponents([.month], from: startDate, to: target).month ?? 0)
            case .year:
                return max(4, calendar.dateComponents([.year], from: startDate, to: target).year ?? 0)
            }
        case .indefinite:
            return maxCellCapacity
        }
    }
    
    // Calculate which "page" of the grid we're on and cells for that page
    var gridPageInfo: (currentPage: Int, totalPages: Int, cellsInCurrentPage: Int, filledInCurrentPage: Int) {
        let totalDuration = totalDurationCells
        let capacity = maxCellCapacity
        let elapsed = elapsedCells
        
        if totalDuration <= capacity {
            // Fits in one grid
            return (0, 1, totalDuration, min(elapsed, totalDuration))
        }
        
        // Multiple pages needed
        let totalPages = Int(ceil(Double(totalDuration) / Double(capacity)))
        let currentPage = min(elapsed / capacity, totalPages - 1)
        
        // Cells in current page
        let cellsBeforeThisPage = currentPage * capacity
        let remainingCells = totalDuration - cellsBeforeThisPage
        let cellsInCurrentPage = min(remainingCells, capacity)
        
        // Filled cells in current page
        let elapsedInCurrentPage = elapsed - cellsBeforeThisPage
        let filledInCurrentPage = max(0, min(elapsedInCurrentPage, cellsInCurrentPage))
        
        return (currentPage, totalPages, cellsInCurrentPage, filledInCurrentPage)
    }
    
    // Goal cell index within current page (nil for indefinite duration)
    var goalCellIndexInCurrentPage: Int? {
        // No goal cell for indefinite duration
        guard durationType != .indefinite else { return nil }
        
        let pageInfo = gridPageInfo
        
        // Goal cell only appears on the last page
        guard pageInfo.currentPage == pageInfo.totalPages - 1 else { return nil }
        
        // Goal cell is the last cell in the current page
        return pageInfo.cellsInCurrentPage - 1
    }
    
    // Whether the habit goal has been reached
    var isGoalReached: Bool {
        guard durationType != .indefinite else { return false }
        return elapsedCells >= totalDurationCells
    }
    
    // Elapsed cells (time passed)
    var elapsedCells: Int {
        if updateMode == .manual {
            return currentValue
        }
        
        let calendar = Calendar.current
        let now = Date()
        let referenceDate = lastResetDate ?? startDate
        
        switch cellUnit {
        case .day:
            return max(0, calendar.dateComponents([.day], from: referenceDate, to: now).day ?? 0)
        case .week:
            let days = calendar.dateComponents([.day], from: referenceDate, to: now).day ?? 0
            return max(0, days / 7)
        case .month:
            return max(0, calendar.dateComponents([.month], from: referenceDate, to: now).month ?? 0)
        case .year:
            return max(0, calendar.dateComponents([.year], from: referenceDate, to: now).year ?? 0)
        }
    }
    
    // Calculate total cells based on settings (for current grid page)
    var totalCells: Int {
        return gridPageInfo.cellsInCurrentPage
    }
    
    // Grid dimensions based on widget size and total cells
    // Cells will resize to fill the available space
    var gridDimensions: (columns: Int, rows: Int) {
        let total = totalCells
        
        switch widgetSize {
        case .half:
            // Small: Square-ish, max 7x7
            let maxCols = 7
            let maxRows = 7
            
            // Try to make it as square as possible
            let side = Int(ceil(sqrt(Double(total))))
            let cols = min(side, maxCols)
            let rows = Int(ceil(Double(total) / Double(cols)))
            return (cols, min(rows, maxRows))
            
        case .fullMedium:
            // Medium: Wide rectangle, max 15x7
            // Aim for roughly 2:1 aspect ratio (width:height)
            let maxCols = 15
            let maxRows = 7
            
            // Calculate ideal dimensions for ~2:1 ratio
            // cols ≈ 2 * rows, cols * rows ≈ total
            // So rows ≈ sqrt(total/2), cols ≈ 2*rows
            let idealRows = max(1, Int(ceil(sqrt(Double(total) / 2.0))))
            let idealCols = Int(ceil(Double(total) / Double(idealRows)))
            
            let cols = min(idealCols, maxCols)
            let rows = min(Int(ceil(Double(total) / Double(cols))), maxRows)
            return (cols, rows)
            
        case .full:
            // Large: Wide rectangle, max 15x14
            // Aim for roughly 1:1 to 2:1 ratio
            let maxCols = 15
            let maxRows = 14
            
            let idealRows = max(1, Int(ceil(sqrt(Double(total) / 1.5))))
            let idealCols = Int(ceil(Double(total) / Double(idealRows)))
            
            let cols = min(idealCols, maxCols)
            let rows = min(Int(ceil(Double(total) / Double(cols))), maxRows)
            return (cols, rows)
        }
    }
    
    // Actual cell count to display (grid might have extra slots)
    var displayCellCount: Int {
        let dims = gridDimensions
        return min(totalCells, dims.columns * dims.rows)
    }
    
    // Current filled cells for display
    func filledCells(at date: Date = Date()) -> Int {
        return gridPageInfo.filledInCurrentPage
    }
}

enum HabitColor: String, Codable, CaseIterable {
    case blue, green, purple, orange, red, pink, teal, yellow
    
    var color: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        case .pink: return .pink
        case .teal: return .teal
        case .yellow: return .yellow
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .blue: return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .green: return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .purple: return LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .orange: return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .red: return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .pink: return LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .teal: return LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .yellow: return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// MARK: - Habit Manager
class HabitManager: ObservableObject {
    @Published var habits: [Habit] = []
    
    private let saveKey = "savedHabits"
    
    // Computed properties for filtering
    var activeHabits: [Habit] {
        habits.filter { !$0.isCompleted }
    }
    
    var completedHabits: [Habit] {
        habits.filter { $0.isCompleted }.sorted { ($0.completedAt ?? Date()) > ($1.completedAt ?? Date()) }
    }
    
    // Stats for habits
    var totalHabitsCreated: Int {
        habits.count
    }
    
    var totalHabitsCompleted: Int {
        completedHabits.count
    }
    
    var currentStreak: Int {
        // Calculate streak based on consecutive days with at least one habit marked
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())
        
        while true {
            let hasActivity = activeHabits.contains { habit in
                if habit.updateMode == .manual {
                    let dayIndex = calendar.dateComponents([.day], from: calendar.startOfDay(for: habit.startDate), to: checkDate).day ?? 0
                    return habit.manuallyFilledCells.contains(dayIndex)
                }
                return false
            }
            
            if hasActivity || streak == 0 {
                if hasActivity { streak += 1 }
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
            
            // Safety limit
            if streak > 365 { break }
        }
        
        return streak
    }
    
    init() {
        load()
        debugWidgetSync()
    }
    func debugWidgetSync() {
        print("🔍 DEBUG: Checking App Group...")
        
        guard let defaults = UserDefaults(suiteName: "group.com.gunisharma.com") else {
            print("❌ Cannot access App Group - check App Group is enabled for main app target")
            return
        }
        
        // Try to save
        if let encoded = try? JSONEncoder().encode(habits) {
            defaults.set(encoded, forKey: "sharedHabits")
            print("✅ Saved \(habits.count) habits to App Group (\(encoded.count) bytes)")
        }
        
        // Try to read back
        if let data = defaults.data(forKey: "sharedHabits"),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            print("✅ Read back \(decoded.count) habits from App Group")
            for habit in decoded {
                print("   - \(habit.name) (completed: \(habit.isCompleted))")
            }
        } else {
            print("❌ Could not read habits from App Group")
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
        syncToWidget()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = decoded
        }
    }
    
    func addHabit(_ habit: Habit) {
        habits.append(habit)
        save()
    }
    
    func deleteHabit(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        save()
    }
    
    func updateHabit(_ habit: Habit) {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            habits[index] = habit
            save()
        }
    }
    
    func completeHabit(_ habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            h.isCompleted = true
            h.completedAt = Date()
            updateHabit(h)
        }
    }
    
    func uncompleteHabit(_ habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            h.isCompleted = false
            h.completedAt = nil
            updateHabit(h)
        }
    }
    
    func incrementProgress(for habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            // Get the current cell index based on elapsed time
            let cellIndex = h.currentCellIndex
            let gridCapacity = h.gridDimensions.columns * h.gridDimensions.rows
            
            // For indefinite habits, wrap the index within current cycle
            let effectiveIndex = h.durationType == .indefinite ? cellIndex % gridCapacity : cellIndex
            
            // Toggle the cell - if already filled, unfill it; otherwise fill it
            if h.manuallyFilledCells.contains(effectiveIndex) {
                h.manuallyFilledCells.remove(effectiveIndex)
            } else {
                h.manuallyFilledCells.insert(effectiveIndex)
            }
            
            // Update currentValue to match the count (for compatibility)
            h.currentValue = h.manuallyFilledCells.count
            
            // Handle cycling for indefinite habits
            if h.durationType == .indefinite && effectiveIndex >= gridCapacity - 1 {
                // Check if we should cycle (all cells in range filled or time moved on)
                let maxFilledIndex = h.manuallyFilledCells.max() ?? 0
                if maxFilledIndex >= gridCapacity - 1 {
                    h.manuallyFilledCells.removeAll()
                    h.cycleCount += 1
                    h.currentValue = 0
                }
            }
            
            updateHabit(h)
        }
    }
    
    func resetProgress(for habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            h.currentValue = 0
            h.cycleCount = 0
            h.manuallyFilledCells.removeAll()
            h.lastResetDate = Date()  // Reset point for auto-tracking
            h.goalNotificationSent = false  // Allow notification for new goal
            updateHabit(h)
        }
    }
    
    // Check all habits and send notifications for newly reached goals
    func checkAndSendGoalNotifications() {
        for habit in habits {
            // Skip if already notified, completed, or indefinite
            guard !habit.goalNotificationSent,
                  !habit.isCompleted,
                  habit.durationType != .indefinite,
                  habit.isGoalReached else { continue }
            
            // Send notification
            sendGoalReachedNotification(for: habit)
            
            // Mark as notified
            if var h = habits.first(where: { $0.id == habit.id }) {
                h.goalNotificationSent = true
                updateHabit(h)
            }
        }
    }
    
    private func sendGoalReachedNotification(for habit: Habit) {
        let content = UNMutableNotificationContent()
        content.title = "🎉 Goal Reached!"
        content.body = "You've completed your \"\(habit.name)\" goal!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "goal_reached_\(habit.id.uuidString)",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error sending goal notification: \(error)")
            }
        }
    }
    
    func addNote(to habit: Habit, content: String) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            let note = HabitNote(content: content)
            h.notes.insert(note, at: 0)  // Add to beginning (newest first)
            updateHabit(h)
        }
    }
    
    func deleteNote(from habit: Habit, noteID: UUID) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            h.notes.removeAll { $0.id == noteID }
            updateHabit(h)
        }
    }
    
    func moveHabit(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              sourceIndex >= 0, sourceIndex < habits.count,
              destinationIndex >= 0, destinationIndex < habits.count else { return }
        
        let habit = habits.remove(at: sourceIndex)
        habits.insert(habit, at: destinationIndex)
        save()
    }
    
    // Move habit by ID - handles filtered lists correctly
    func moveHabitByID(from sourceID: UUID, to targetID: UUID) {
        guard let fromIndex = habits.firstIndex(where: { $0.id == sourceID }),
              let toIndex = habits.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else { return }
        
        let habit = habits.remove(at: fromIndex)
        habits.insert(habit, at: toIndex)
        save()
    }
}

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

// MARK: - Progress Grid View (fills from top-left to right, like reading)
struct ContributionGridView: View {
    let habit: Habit
    let showFullGrid: Bool  // For detail view
    
    init(habit: Habit, showFullGrid: Bool = false) {
        self.habit = habit
        self.showFullGrid = showFullGrid
    }
    
    private var isSmall: Bool { habit.widgetSize == .half }
    private var isLarge: Bool { habit.widgetSize == .full }
    
    // Fixed card heights - Small/Medium same, Large is 2x
    private var cardHeight: CGFloat {
        switch habit.widgetSize {
        case .half: return 160
        case .fullMedium: return 160
        case .full: return 320
        }
    }
    
    private var dimensions: (columns: Int, rows: Int) {
        habit.gridDimensions
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                
                // Progress label
                Text(progressLabel)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Grid - takes remaining space
            GridContent(
                columns: dimensions.columns,
                rows: dimensions.rows,
                filledCells: filledCellsForDisplay,
                totalCells: habit.totalCells,
                color: habit.color.color,
                spacing: isSmall ? 3 : 4,
                isCountdown: habit.type == .countdown,
                isManualMode: habit.updateMode == .manual,
                manuallyFilledCells: habit.manuallyFilledCells,
                currentCellIndex: habit.currentCellIndex,
                goalCellIndex: habit.goalCellIndexInCurrentPage
            )
        }
        .padding(12)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var filledCellsForDisplay: Int {
        let filled = habit.filledCells()
        
        if habit.type == .countdown {
            // Countdown: show remaining cells as filled (inverse)
            return max(0, habit.totalCells - filled)
        } else {
            return filled
        }
    }
    
    private var progressLabel: String {
        let pageInfo = habit.gridPageInfo
        let totalDuration = habit.totalDurationCells
        
        let unitSuffix: String
        switch habit.cellUnit {
        case .day: unitSuffix = "d"
        case .week: unitSuffix = "w"
        case .month: unitSuffix = "mo"
        case .year: unitSuffix = "y"
        }
        
        if habit.updateMode == .manual {
            // For manual mode, show filled cells / total cells
            let filledCount = habit.manuallyFilledCells.count
            if habit.durationType == .indefinite {
                let cycleInfo = habit.cycleCount > 0 ? " (×\(habit.cycleCount + 1))" : ""
                return "\(filledCount)/\(pageInfo.cellsInCurrentPage)\(cycleInfo)"
            }
            return "\(filledCount)/\(totalDuration)"
        }
        
        // Auto mode - show elapsed time
        let elapsed = habit.elapsedCells
        
        if habit.durationType == .indefinite {
            let cycleInfo = habit.cycleCount > 0 ? " (×\(habit.cycleCount + 1))" : ""
            return "\(pageInfo.filledInCurrentPage)/\(pageInfo.cellsInCurrentPage)\(cycleInfo)"
        }
        
        // Show overall progress + page if multiple pages
        if pageInfo.totalPages > 1 {
            return "\(elapsed)/\(totalDuration)\(unitSuffix) (\(pageInfo.currentPage + 1)/\(pageInfo.totalPages))"
        }
        
        return "\(elapsed)/\(totalDuration)\(unitSuffix)"
    }
}

// Separate grid content view - cells resize to fill available space
struct GridContent: View {
    let columns: Int
    let rows: Int
    let filledCells: Int
    let totalCells: Int  // Actual number of cells to display
    let color: Color
    let spacing: CGFloat
    let isCountdown: Bool
    let isManualMode: Bool
    let manuallyFilledCells: Set<Int>
    let currentCellIndex: Int  // Today's cell index
    let goalCellIndex: Int?    // Index of the goal cell (nil for indefinite)
    
    // Beautiful gold color for goal cell
    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.9, blue: 0.4),
            Color(red: 1.0, green: 0.75, blue: 0.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            
            let totalHSpacing = spacing * CGFloat(columns - 1)
            let totalVSpacing = spacing * CGFloat(rows - 1)
            
            // Calculate cell size to fill available space (cells stretch to fill)
            let cellWidth = (availableWidth - totalHSpacing) / CGFloat(columns)
            let cellHeight = (availableHeight - totalVSpacing) / CGFloat(rows)
            let cornerRadius = min(cellWidth, cellHeight) * 0.15
            
            VStack(spacing: spacing) {
                ForEach(Array(0..<rows), id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(Array(0..<columns), id: \.self) { col in
                            let cellIndex = (row * columns) + col
                            
                            if cellIndex < totalCells {
                                // Check if this is the goal cell
                                if cellIndex == goalCellIndex {
                                    // Goal cell - special gold styling
                                    goalCellView(
                                        isFilled: isCellFilled(at: cellIndex),
                                        cornerRadius: cornerRadius,
                                        width: cellWidth,
                                        height: cellHeight
                                    )
                                } else {
                                    RoundedRectangle(cornerRadius: cornerRadius)
                                        .fill(cellColor(at: cellIndex))
                                        .frame(width: cellWidth, height: cellHeight)
                                }
                            } else {
                                // Empty placeholder for alignment
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func goalCellView(isFilled: Bool, cornerRadius: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        if isFilled {
            // Solid gold with subtle shimmer gradient
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(goldGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: goldColor.opacity(0.5), radius: 3, x: 0, y: 0)
                .frame(width: width, height: height)
        } else {
            // Gold outline when unfilled
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(goldGradient, lineWidth: 2)
                )
                .frame(width: width, height: height)
        }
    }
    
    private func cellColor(at index: Int) -> Color {
        if isManualMode {
            // Manual mode: check if this specific cell is in the filled set
            if manuallyFilledCells.contains(index) {
                return color
            } else if index == currentCellIndex {
                // Highlight today's cell with a subtle border/tint if not filled
                return Color.white.opacity(0.25)
            } else if index > currentCellIndex {
                // Future cells are dimmer
                return Color.white.opacity(0.1)
            } else {
                // Past unfilled cells
                return Color.white.opacity(0.15)
            }
        } else {
            // Auto mode: use the original fill logic
            if isCellFilled(at: index) {
                return color
            } else {
                return Color.white.opacity(0.15)
            }
        }
    }
    
    private func isCellFilled(at index: Int) -> Bool {
        if isManualMode {
            return manuallyFilledCells.contains(index)
        }
        
        if isCountdown {
            // Countdown: fill from end, empty from start
            let emptyCount = totalCells - filledCells
            return index >= emptyCount && index < totalCells
        } else {
            // Count up: fill from start
            return index < filledCells
        }
    }
}

// MARK: - Text Counter View
struct TextCounterView: View {
    let habit: Habit
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var isSmall: Bool { habit.widgetSize == .half }
    private var isLarge: Bool { habit.widgetSize == .full }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 8 : 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                
                // Show countdown/countup label
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
            
            if isSmall {
                // Small: Show primary unit centered
                VStack(spacing: 4) {
                    Text(primaryValue)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.color.gradient)
                    Text(primaryLabel)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            } else {
                // Medium/Large: Multiple time components based on time unit
                HStack(spacing: isLarge ? 16 : 10) {
                    ForEach(timeComponentsForUnit, id: \.label) { component in
                        VStack(spacing: 4) {
                            Text(component.value)
                                .font(.system(size: isLarge ? 32 : 26, weight: .bold, design: .rounded))
                                .foregroundStyle(habit.color.gradient)
                            Text(component.label)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Progress indicator
            if habit.durationType != .indefinite {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(habit.color.gradient)
                            .frame(width: geo.size.width * progressToTarget)
                    }
                    .frame(height: 6)
                }
            }
        }
        .padding(12)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // Match grid heights - Small/Medium same, Large is 2x
    private var cardHeight: CGFloat {
        switch habit.widgetSize {
        case .half: return 160
        case .fullMedium: return 160
        case .full: return 320
        }
    }
    
    // Calculate target date for text counter based on duration and time unit
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate {
            return target
        }
        
        // Calculate target from duration
        let calendar = Calendar.current
        let duration = habit.textCounterDuration
        
        switch habit.timeUnit {
        case .seconds:
            return calendar.date(byAdding: .second, value: duration, to: habit.startDate) ?? habit.startDate
        case .minutes:
            return calendar.date(byAdding: .minute, value: duration, to: habit.startDate) ?? habit.startDate
        case .hours:
            return calendar.date(byAdding: .hour, value: duration, to: habit.startDate) ?? habit.startDate
        case .days:
            return calendar.date(byAdding: .day, value: duration, to: habit.startDate) ?? habit.startDate
        case .weeks:
            return calendar.date(byAdding: .weekOfYear, value: duration, to: habit.startDate) ?? habit.startDate
        case .months:
            return calendar.date(byAdding: .month, value: duration, to: habit.startDate) ?? habit.startDate
        case .years:
            return calendar.date(byAdding: .year, value: duration, to: habit.startDate) ?? habit.startDate
        }
    }
    
    private var timeInterval: TimeInterval {
        if habit.type == .countdown {
            return calculatedTargetDate.timeIntervalSince(currentTime)
        } else {
            return currentTime.timeIntervalSince(habit.startDate)
        }
    }
    
    private var progressToTarget: CGFloat {
        let totalInterval: TimeInterval
        if habit.type == .countdown {
            totalInterval = calculatedTargetDate.timeIntervalSince(habit.startDate)
        } else {
            totalInterval = calculatedTargetDate.timeIntervalSince(habit.startDate)
        }
        
        guard totalInterval > 0 else { return 0 }
        
        let elapsed = currentTime.timeIntervalSince(habit.startDate)
        let progress = CGFloat(min(max(elapsed / totalInterval, 0), 1))
        
        if habit.type == .countdown {
            return 1.0 - progress
        }
        return progress
    }
    
    private var primaryValue: String {
        let interval = abs(timeInterval)
        switch habit.timeUnit {
        case .seconds: return String(format: "%.0f", interval)
        case .minutes: return String(format: "%.0f", interval / 60)
        case .hours: return String(format: "%.1f", interval / 3600)
        case .days: return String(format: "%.0f", interval / 86400)
        case .weeks: return String(format: "%.1f", interval / 604800)
        case .months: return String(format: "%.1f", interval / 2592000)
        case .years: return String(format: "%.2f", interval / 31536000)
        }
    }
    
    private var primaryLabel: String {
        habit.timeUnit.rawValue.lowercased()
    }
    
    private struct TimeComponent {
        let value: String
        let label: String
    }
    
    // Time components based on the selected time unit
    // If days selected: days:hours:minutes:seconds
    // If years selected: years:months:days:hours:minutes:seconds
    private var timeComponentsForUnit: [TimeComponent] {
        let interval = abs(timeInterval)
        
        let totalSeconds = Int(interval)
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let totalHours = totalMinutes / 60
        let hours = totalHours % 24
        let totalDays = totalHours / 24
        let days = totalDays % 7
        let weeks = totalDays / 7
        
        // For months/years, use calendar-based calculation for accuracy
        let calendar = Calendar.current
        let referenceDate = habit.type == .countdown ? currentTime : habit.startDate
        let targetForCalc = habit.type == .countdown ? calculatedTargetDate : currentTime
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: referenceDate, to: targetForCalc)
        
        let years = abs(components.year ?? 0)
        let months = abs(components.month ?? 0)
        let calendarDays = abs(components.day ?? 0)
        let calendarHours = abs(components.hour ?? 0)
        let calendarMinutes = abs(components.minute ?? 0)
        let calendarSeconds = abs(components.second ?? 0)
        
        switch habit.timeUnit {
        case .seconds:
            return [
                TimeComponent(value: "\(totalSeconds)", label: "sec")
            ]
            
        case .minutes:
            return [
                TimeComponent(value: "\(totalMinutes)", label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
            ]
            
        case .hours:
            return [
                TimeComponent(value: "\(totalHours)", label: "hrs"),
                TimeComponent(value: String(format: "%02d", minutes), label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
            ]
            
        case .days:
            return [
                TimeComponent(value: "\(totalDays)", label: "days"),
                TimeComponent(value: String(format: "%02d", hours), label: "hrs"),
                TimeComponent(value: String(format: "%02d", minutes), label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
            ]
            
        case .weeks:
            return [
                TimeComponent(value: "\(weeks)", label: "wks"),
                TimeComponent(value: "\(days)", label: "days"),
                TimeComponent(value: String(format: "%02d", hours), label: "hrs"),
                TimeComponent(value: String(format: "%02d", minutes), label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
            ]
            
        case .months:
            return [
                TimeComponent(value: "\(months)", label: "mon"),
                TimeComponent(value: "\(calendarDays)", label: "days"),
                TimeComponent(value: String(format: "%02d", calendarHours), label: "hrs"),
                TimeComponent(value: String(format: "%02d", calendarMinutes), label: "min"),
                TimeComponent(value: String(format: "%02d", calendarSeconds), label: "sec")
            ]
            
        case .years:
            return [
                TimeComponent(value: "\(years)", label: "yrs"),
                TimeComponent(value: "\(months)", label: "mon"),
                TimeComponent(value: "\(calendarDays)", label: "days"),
                TimeComponent(value: String(format: "%02d", calendarHours), label: "hrs"),
                TimeComponent(value: String(format: "%02d", calendarMinutes), label: "min"),
                TimeComponent(value: String(format: "%02d", calendarSeconds), label: "sec")
            ]
        }
    }
}

// MARK: - Timeline Bar View
struct TimelineBarView: View {
    let habit: Habit
    
    @State private var currentTime = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var isSmall: Bool { habit.widgetSize == .half }
    private var isLarge: Bool { habit.widgetSize == .full }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            // Time display
            Text(mainTimeDisplay)
                .font(.system(size: isSmall ? 20 : (isLarge ? 28 : 24), weight: .bold, design: .rounded))
                .foregroundStyle(habit.color.gradient)
                .frame(maxWidth: .infinity, alignment: isSmall ? .center : .leading)
            
            // Progress info
            HStack {
                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(elapsedTicks) / \(totalTicks) \(habit.timelineTickUnit.displayName.lowercased())")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer(minLength: 0)
            
            // Timeline with ticks
            GeometryReader { geo in
                let tickCount = min(totalTicks, maxVisibleTicks)
                let tickSpacing = tickCount > 1 ? geo.size.width / CGFloat(tickCount) : geo.size.width
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.15))
                        .frame(height: isLarge ? 8 : 6)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(habit.color.gradient)
                        .frame(width: geo.size.width * progress, height: isLarge ? 8 : 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    // Tick marks
                    ForEach(0..<tickCount + 1, id: \.self) { index in
                        let xPosition = CGFloat(index) * tickSpacing
                        let isFilled = isTickFilled(index: index, totalTicks: tickCount)
                        
                        Rectangle()
                            .fill(isFilled ? habit.color.color : .white.opacity(0.3))
                            .frame(width: isLarge ? 2 : 1.5, height: isLarge ? 20 : 16)
                            .position(x: xPosition, y: (isLarge ? 20 : 16) / 2)
                    }
                }
                .frame(height: isLarge ? 20 : 16)
            }
            .frame(height: isLarge ? 20 : 16)
            
            // Tick labels (only show a few key labels)
            if !isSmall {
                HStack {
                    Text(startLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    if totalTicks > 2 {
                        Text(middleLabel)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                    Text(endLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            currentTime = Date()
        }
    }
    
    // Match grid heights
    private var cardHeight: CGFloat {
        switch habit.widgetSize {
        case .half: return 160
        case .fullMedium: return 160
        case .full: return 320
        }
    }
    
    // Maximum visible ticks based on widget size
    private var maxVisibleTicks: Int {
        switch habit.widgetSize {
        case .half: return 10
        case .fullMedium: return 20
        case .full: return 30
        }
    }
    
    // Calculate target date based on timeline settings
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate {
            return target
        }
        
        let calendar = Calendar.current
        let duration = habit.timelineDuration
        
        switch habit.timelineTickUnit {
        case .minute:
            return calendar.date(byAdding: .minute, value: duration, to: habit.startDate) ?? habit.startDate
        case .hour:
            return calendar.date(byAdding: .hour, value: duration, to: habit.startDate) ?? habit.startDate
        case .day:
            return calendar.date(byAdding: .day, value: duration, to: habit.startDate) ?? habit.startDate
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: duration, to: habit.startDate) ?? habit.startDate
        case .month:
            return calendar.date(byAdding: .month, value: duration, to: habit.startDate) ?? habit.startDate
        case .year:
            return calendar.date(byAdding: .year, value: duration, to: habit.startDate) ?? habit.startDate
        }
    }
    
    // Total number of ticks (total duration in tick units)
    private var totalTicks: Int {
        if habit.durationType == .toTargetDate, let target = habit.targetDate {
            return calculateTicksBetween(from: habit.startDate, to: target)
        }
        return habit.timelineDuration
    }
    
    // Elapsed ticks
    private var elapsedTicks: Int {
        let ticks = calculateTicksBetween(from: habit.startDate, to: currentTime)
        return min(max(0, ticks), totalTicks)
    }
    
    private func calculateTicksBetween(from startDate: Date, to endDate: Date) -> Int {
        let calendar = Calendar.current
        
        switch habit.timelineTickUnit {
        case .minute:
            return calendar.dateComponents([.minute], from: startDate, to: endDate).minute ?? 0
        case .hour:
            return calendar.dateComponents([.hour], from: startDate, to: endDate).hour ?? 0
        case .day:
            return calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        case .week:
            let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return days / 7
        case .month:
            return calendar.dateComponents([.month], from: startDate, to: endDate).month ?? 0
        case .year:
            return calendar.dateComponents([.year], from: startDate, to: endDate).year ?? 0
        }
    }
    
    // Progress (0-1)
    private var progress: CGFloat {
        guard totalTicks > 0 else { return 0 }
        let rawProgress = CGFloat(elapsedTicks) / CGFloat(totalTicks)
        let clampedProgress = min(max(rawProgress, 0), 1)
        
        // For countdown: start full, decrease over time
        // For count up: start empty, increase over time
        if habit.type == .countdown {
            return 1.0 - clampedProgress
        }
        return clampedProgress
    }
    
    private func isTickFilled(index: Int, totalTicks: Int) -> Bool {
        guard totalTicks > 0 else { return false }
        let tickProgress = CGFloat(index) / CGFloat(totalTicks)
        
        if habit.type == .countdown {
            // Countdown: ticks after the remaining time are empty
            return tickProgress >= (1.0 - progress)
        } else {
            // Count up: ticks before elapsed time are filled
            return tickProgress <= progress
        }
    }
    
    private var progressText: String {
        if habit.type == .countdown {
            String(format: "%.1f%% remaining", progress * 100)
        } else {
            String(format: "%.1f%% complete", progress * 100)
        }
    }
    
    private var startLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = habit.timelineTickUnit == .minute || habit.timelineTickUnit == .hour ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: habit.startDate)
    }
    
    private var middleLabel: String {
        let midTicks = totalTicks / 2
        return "\(midTicks) \(habit.timelineTickUnit.displayName.lowercased())"
    }
    
    private var endLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = habit.timelineTickUnit == .minute || habit.timelineTickUnit == .hour ? "MMM d, h:mm a" : "MMM d"
        return formatter.string(from: calculatedTargetDate)
    }
    
    private var mainTimeDisplay: String {
        let remaining = totalTicks - elapsedTicks
        let displayValue = habit.type == .countdown ? remaining : elapsedTicks
        
        // Show in the same unit as the tick
        switch habit.timelineTickUnit {
        case .minute:
            let hrs = displayValue / 60
            let mins = displayValue % 60
            if hrs > 0 {
                return "\(hrs)h \(mins)m"
            }
            return "\(mins)m"
        case .hour:
            let days = displayValue / 24
            let hrs = displayValue % 24
            if days > 0 {
                return "\(days)d \(hrs)h"
            }
            return "\(hrs)h"
        case .day:
            let weeks = displayValue / 7
            let days = displayValue % 7
            if weeks > 0 {
                return "\(weeks)w \(days)d"
            }
            return "\(days) days"
        case .week:
            let months = displayValue / 4
            let weeks = displayValue % 4
            if months > 0 {
                return "\(months)mo \(weeks)w"
            }
            return "\(weeks) weeks"
        case .month:
            let years = displayValue / 12
            let months = displayValue % 12
            if years > 0 {
                return "\(years)y \(months)mo"
            }
            return "\(months) months"
        case .year:
            return "\(displayValue) years"
        }
    }
}

// MARK: - Add Habit Sheet
struct AddHabitSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    
    @State private var name = ""
    @State private var icon = "target"
    @State private var habitType: HabitType = .countUp
    @State private var updateMode: HabitUpdateMode = .auto
    @State private var visualStyle: HabitVisualStyle = .grid
    @State private var widgetSize: HabitWidgetSize = .full
    
    // Grid settings
    @State private var cellUnit: CellUnit = .day
    @State private var durationType: GridDurationType = .customRange
    @State private var customDuration: Int = 30
    @State private var targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    
    // Timeline bar settings
    @State private var barDurationType: BarDurationType = .customRange
    @State private var timelineTickUnit: TimelineTickUnit = .day
    @State private var timelineDuration: Int = 30
    
    // Display settings
    @State private var timeUnit: HabitTimeUnit = .days
    @State private var color: HabitColor = .blue
    @State private var textCounterDuration: Int = 30
    
    @State private var currentPreviewPage = 0
    
    // Duration range for text counter based on time unit
    private var textCounterDurationRange: ClosedRange<Int> {
        switch timeUnit {
        case .seconds: return 1...3600
        case .minutes: return 1...1440
        case .hours: return 1...720
        case .days: return 1...365
        case .weeks: return 1...104
        case .months: return 1...120
        case .years: return 1...100
        }
    }
    
    // Description of display format based on time unit
    private var timeUnitDisplayFormatDescription: String {
        switch timeUnit {
        case .seconds:
            return "Displays: seconds"
        case .minutes:
            return "Displays: minutes : seconds"
        case .hours:
            return "Displays: hours : minutes : seconds"
        case .days:
            return "Displays: days : hours : minutes : seconds"
        case .weeks:
            return "Displays: weeks : days : hours : minutes : seconds"
        case .months:
            return "Displays: months : days : hours : minutes : seconds"
        case .years:
            return "Displays: years : months : days : hours : minutes : seconds"
        }
    }
    
    // Duration range for timeline based on tick unit
    private var timelineDurationRange: ClosedRange<Int> {
        switch timelineTickUnit {
        case .minute: return 1...1440    // up to 24 hours
        case .hour: return 1...720       // up to 30 days
        case .day: return 1...365        // up to 1 year
        case .week: return 1...104       // up to 2 years
        case .month: return 1...120      // up to 10 years
        case .year: return 1...100       // up to 100 years
        }
    }
    
    // Description of timeline preview
    private var timelinePreviewDescription: String {
        let tickLabel = timelineTickUnit.displayName.lowercased()
        if barDurationType == .customRange {
            return "Timeline with \(timelineDuration) ticks, each representing 1 \(timelineTickUnit.singularName)"
        } else {
            return "Timeline to target date, each tick represents 1 \(timelineTickUnit.singularName)"
        }
    }
    
    // Display name for current style in preview header
    private var currentStyleDisplayName: String {
        let style = HabitVisualStyle.allCases[currentPreviewPage]
        switch style {
        case .grid: return "Grid"
        case .text: return "Timer"
        case .bar: return "Timeline"
        }
    }
    
    // Minimum target date (4 units from now)
    private var minimumTargetDate: Date {
        let calendar = Calendar.current
        switch cellUnit {
        case .day:
            return calendar.date(byAdding: .day, value: 4, to: Date()) ?? Date()
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: 4, to: Date()) ?? Date()
        case .month:
            return calendar.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        case .year:
            return calendar.date(byAdding: .year, value: 4, to: Date()) ?? Date()
        }
    }
    
    // Range limits for custom duration
    private var customDurationRange: ClosedRange<Int> {
        switch cellUnit {
        case .day: return 4...365
        case .week: return 4...104
        case .month: return 4...120
        case .year: return 4...50
        }
    }
    
    private let icons = [
        "target", "flame.fill", "star.fill", "heart.fill",
        "book.fill", "dumbbell.fill", "drop.fill", "leaf.fill",
        "moon.fill", "sun.max.fill", "bolt.fill", "checkmark.seal.fill",
        "trophy.fill", "flag.fill", "bell.fill", "clock.fill"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Style Preview Carousel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(currentStyleDisplayName)
                                .font(.title2.bold())
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Swipe indicator
                            HStack(spacing: 4) {
                                ForEach(0..<HabitVisualStyle.allCases.count, id: \.self) { index in
                                    Circle()
                                        .fill(index == currentPreviewPage ? color.color : Color.secondary.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .animation(.easeInOut(duration: 0.2), value: currentPreviewPage)
                        
                        TabView(selection: $currentPreviewPage) {
                            ForEach(Array(HabitVisualStyle.allCases.enumerated()), id: \.element) { index, style in
                                PreviewCard(style: style, habit: previewHabit(for: style))
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 200)
                        .onChange(of: currentPreviewPage) { _, newValue in
                            visualStyle = HabitVisualStyle.allCases[newValue]
                        }
                    }
                    
                    // Name & Icon Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Name & Icon")
                            .font(.headline)
                        
                        TextField("Habit name", text: $name)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                            ForEach(icons, id: \.self) { iconName in
                                Button {
                                    icon = iconName
                                } label: {
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundColor(icon == iconName ? color.color : .secondary)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            Circle()
                                                .fill(icon == iconName ? color.color.opacity(0.2) : Color(.secondarySystemGroupedBackground))
                                        )
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Tracking Type Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Tracking Type")
                            .font(.headline)
                        
                        VStack(spacing: 12) {
                            Picker("Type", selection: $habitType) {
                                ForEach(HabitType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                            
                            // Manual mode only available for grid style
                            if visualStyle == .grid {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Update Mode")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Update Mode", selection: $updateMode) {
                                        ForEach(HabitUpdateMode.allCases, id: \.self) { mode in
                                            Text(mode.rawValue).tag(mode)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .onChange(of: visualStyle) { _, newStyle in
                        if newStyle != .grid {
                            updateMode = .auto
                        }
                        // Reset duration type for bar (no indefinite)
                        if newStyle == .bar && durationType == .indefinite {
                            durationType = .customRange
                        }
                    }
                    
                    // Grid Settings Section
                    if visualStyle == .grid {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Grid Settings")
                                .font(.headline)
                            
                            VStack(spacing: 16) {
                                // Cell unit
                                HStack {
                                    Text("Each cell represents")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("Cell Unit", selection: $cellUnit) {
                                        ForEach(CellUnit.allCases, id: \.self) { unit in
                                            Text("1 \(unit.displayName)").tag(unit)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(color.color)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                
                                // Duration type
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Duration")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Duration", selection: $durationType) {
                                        ForEach(GridDurationType.allCases, id: \.self) { type in
                                            Text(type.displayName).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                
                                // Duration value input
                                switch durationType {
                                case .customRange:
                                    HStack {
                                        Text("Duration")
                                        Spacer()
                                        Stepper(
                                            "\(customDuration) \(cellUnit.pluralName)",
                                            value: $customDuration,
                                            in: customDurationRange
                                        )
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    
                                case .toTargetDate:
                                    DatePicker(
                                        "End Date",
                                        selection: $targetDate,
                                        in: minimumTargetDate...,
                                        displayedComponents: .date
                                    )
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .onChange(of: cellUnit) { _, _ in
                                        if targetDate < minimumTargetDate {
                                            targetDate = minimumTargetDate
                                        }
                                    }
                                    
                                case .indefinite:
                                    HStack {
                                        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
                                            .foregroundColor(color.color)
                                        Text("Grid will cycle when filled")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Timeline Bar Settings Section
                    if visualStyle == .bar {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Timeline Settings")
                                .font(.headline)
                            
                            VStack(spacing: 16) {
                                // Duration type
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Duration Type")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Duration", selection: $barDurationType) {
                                        ForEach(BarDurationType.allCases, id: \.self) { type in
                                            Text(type.displayName).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: barDurationType) { _, newValue in
                                        durationType = newValue.toGridDurationType
                                    }
                                }
                                
                                // Tick unit - what each tick represents
                                HStack {
                                    Text("Each tick represents")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("Tick Unit", selection: $timelineTickUnit) {
                                        ForEach(TimelineTickUnit.allCases, id: \.self) { unit in
                                            Text("1 \(unit.singularName)").tag(unit)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(color.color)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                
                                // Duration value
                                switch barDurationType {
                                case .customRange:
                                    HStack {
                                        Text("Duration")
                                        Spacer()
                                        Stepper(
                                            "\(timelineDuration) \(timelineTickUnit.displayName.lowercased())",
                                            value: $timelineDuration,
                                            in: timelineDurationRange
                                        )
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    
                                case .toTargetDate:
                                    DatePicker(
                                        "Target Date",
                                        selection: $targetDate,
                                        in: Date()...,
                                        displayedComponents: timelineTickUnit == .minute || timelineTickUnit == .hour ? [.date, .hourAndMinute] : [.date]
                                    )
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                }
                                
                                // Preview info
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Timeline Preview")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(timelinePreviewDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Text Counter Settings
                    if visualStyle == .text {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Counter Settings")
                                .font(.headline)
                            
                            VStack(spacing: 16) {
                                // Duration type
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Duration Type")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("Duration", selection: $barDurationType) {
                                        ForEach(BarDurationType.allCases, id: \.self) { type in
                                            Text(type.displayName).tag(type)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .onChange(of: barDurationType) { _, newValue in
                                        durationType = newValue.toGridDurationType
                                    }
                                }
                                
                                // Time range selection - determines display format
                                HStack {
                                    Text("Time Range")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("Time Unit", selection: $timeUnit) {
                                        ForEach(HabitTimeUnit.allCases, id: \.self) { unit in
                                            Text(unit.rawValue).tag(unit)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(color.color)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(10)
                                
                                // Duration value
                                switch barDurationType {
                                case .customRange:
                                    HStack {
                                        Text("Duration")
                                        Spacer()
                                        Stepper(
                                            "\(textCounterDuration) \(timeUnit.rawValue.lowercased())",
                                            value: $textCounterDuration,
                                            in: textCounterDurationRange
                                        )
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    
                                case .toTargetDate:
                                    DatePicker(
                                        "Target Date",
                                        selection: $targetDate,
                                        in: Date()...,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(10)
                                }
                                
                                // Display format preview
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Display Format")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(timeUnitDisplayFormatDescription)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Widget Size Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Widget Size")
                            .font(.headline)
                        
                        Picker("Widget Size", selection: $widgetSize) {
                            ForEach(HabitWidgetSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    
                    // Color Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Color")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 14) {
                            ForEach(HabitColor.allCases, id: \.self) { c in
                                Button {
                                    color = c
                                } label: {
                                    Circle()
                                        .fill(c.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: color == c ? 3 : 0)
                                        )
                                        .shadow(color: c.color.opacity(0.5), radius: color == c ? 6 : 0)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHabit()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private func previewHabit(for style: HabitVisualStyle) -> Habit {
        var habit = Habit(
            name: name.isEmpty ? "My Habit" : name,
            icon: icon,
            type: habitType,
            updateMode: style == .grid ? updateMode : .auto,
            visualStyle: style,
            widgetSize: .full,
            cellUnit: cellUnit,
            durationType: style == .bar || style == .text ? barDurationType.toGridDurationType : durationType,
            customDuration: customDuration,
            targetDate: (durationType == .toTargetDate || barDurationType == .toTargetDate) ? targetDate : nil,
            textCounterDuration: textCounterDuration,
            timelineTickUnit: timelineTickUnit,
            timelineDuration: timelineDuration,
            timeUnit: timeUnit,
            color: color
        )
        
        // Set sample progress for preview (about 1/3 filled)
        if habit.updateMode == .manual {
            // For manual mode, fill some specific cells
            let cellsToFill = habit.totalDurationCells / 3
            for i in 0..<cellsToFill {
                habit.manuallyFilledCells.insert(i)
            }
            habit.currentValue = habit.manuallyFilledCells.count
        } else {
            habit.currentValue = habit.totalDurationCells / 3
        }
        
        return habit
    }
    
    private func addHabit() {
        let finalDurationType = (visualStyle == .bar || visualStyle == .text) ? barDurationType.toGridDurationType : durationType
        let habit = Habit(
            name: name,
            icon: icon,
            type: habitType,
            updateMode: visualStyle == .grid ? updateMode : .auto,
            visualStyle: visualStyle,
            widgetSize: widgetSize,
            cellUnit: cellUnit,
            durationType: finalDurationType,
            customDuration: customDuration,
            targetDate: (finalDurationType == .toTargetDate || habitType == .countdown) ? targetDate : nil,
            textCounterDuration: textCounterDuration,
            timelineTickUnit: timelineTickUnit,
            timelineDuration: timelineDuration,
            timeUnit: timeUnit,
            color: color
        )
        habitManager.addHabit(habit)
    }
}

// MARK: - Preview Card for Style Selection
struct PreviewCard: View {
    let style: HabitVisualStyle
    let habit: Habit
    
    var body: some View {
        ZStack {
            // Dark background to match tracker view
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.12, blue: 0.3), Color(red: 0.2, green: 0.15, blue: 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Preview content - use half size widget which is 160pt tall
            Group {
                switch style {
                case .grid:
                    ContributionGridView(habit: previewHabit)
                case .text:
                    TextCounterView(habit: previewHabit)
                case .bar:
                    TimelineBarView(habit: previewHabit)
                }
            }
            .padding(4)
            .allowsHitTesting(false)
        }
        .padding(.horizontal, 20)
    }
    
    // Create preview habit with small (half) size - fits nicely in preview
    private var previewHabit: Habit {
        var h = habit
        h.widgetSize = .half
        return h
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    let habit: Habit
    
    @State private var noteContent = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header info
                HStack(spacing: 12) {
                    Image(systemName: habit.icon)
                        .font(.title2)
                        .foregroundColor(habit.color.color)
                    
                    Text(habit.name)
                        .font(.headline)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Note input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What's on your mind?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $noteContent)
                        .frame(minHeight: 150)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .focused($isFocused)
                }
                .padding(.horizontal)
                
                // Timestamp preview
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            habitManager.addNote(to: habit, content: noteContent.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        dismiss()
                    }
                    .disabled(noteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Notes List Sheet
struct NotesListSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    let habit: Habit
    
    @State private var showAddNote = false
    
    // Get fresh habit data
    private var currentHabit: Habit {
        habitManager.habits.first { $0.id == habit.id } ?? habit
    }
    
    var body: some View {
        NavigationView {
            Group {
                if currentHabit.notes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "note.text")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        Text("No Notes Yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Button {
                            showAddNote = true
                        } label: {
                            Label("Add Your First Note", systemImage: "plus.circle.fill")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(currentHabit.notes) { note in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(note.content)
                                    .font(.body)
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .font(.caption2)
                                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                }
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let note = currentHabit.notes[index]
                                habitManager.deleteNote(from: habit, noteID: note.id)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Notes (\(currentHabit.notes.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteSheet(habitManager: habitManager, habit: currentHabit)
            }
        }
    }
}

// MARK: - Habit Detail/Edit Sheet
struct HabitDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    @State var habit: Habit
    @State private var showAddNote = false
    @State private var showNotesList = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Full Grid Preview (for grid style habits)
                    if habit.visualStyle == .grid {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.12, blue: 0.3), Color(red: 0.2, green: 0.15, blue: 0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            ContributionGridView(habit: habit, showFullGrid: true)
                                .padding(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Settings List
                    VStack(spacing: 0) {
                        // Info Section
                        SettingsSection(title: "Info") {
                            SettingsRow(label: "Name", value: habit.name)
                            SettingsRow(label: "Type", value: habit.type.rawValue)
                            SettingsRow(label: "Started", value: habit.startDate.formatted(date: .abbreviated, time: .omitted))
                            SettingsRow(label: "Cell Unit", value: "1 \(habit.cellUnit.displayName)")
                            SettingsRow(label: "Total Duration", value: "\(habit.totalDurationCells) \(habit.cellUnit.pluralName)")
                            SettingsRow(label: "Current Grid", value: "\(habit.gridDimensions.columns) × \(habit.gridDimensions.rows)")
                            if habit.gridPageInfo.totalPages > 1 {
                                SettingsRow(label: "Grid Page", value: "\(habit.gridPageInfo.currentPage + 1) of \(habit.gridPageInfo.totalPages)")
                            }
                        }
                        
                        // Progress Section (only for manual grid habits)
                        if habit.updateMode == .manual && habit.visualStyle == .grid {
                            SettingsSection(title: "Progress") {
                                HStack {
                                    Text("Cells Filled")
                                    Spacer()
                                    Text("\(habit.manuallyFilledCells.count) / \(habit.totalDurationCells)")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                                
                                HStack {
                                    Text("Current Cell")
                                    Spacer()
                                    Text("\(habit.cellUnit.displayName) \(habit.currentCellIndex + 1)")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemGroupedBackground))
                                
                                Button {
                                    habitManager.incrementProgress(for: habit)
                                    if let updated = habitManager.habits.first(where: { $0.id == habit.id }) {
                                        habit = updated
                                    }
                                } label: {
                                    HStack {
                                        let isTodayFilled = habit.manuallyFilledCells.contains(habit.currentCellIndex)
                                        Image(systemName: isTodayFilled ? "checkmark.circle.fill" : "plus.circle.fill")
                                        Text(isTodayFilled ? "Unmark Today" : "Mark Today Complete")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                }
                                .background(Color(.secondarySystemGroupedBackground))
                            }
                        }
                        
                        // Appearance Section
                        SettingsSection(title: "Appearance") {
                            HStack {
                                Text("Widget Size")
                                Spacer()
                                Picker("", selection: $habit.widgetSize) {
                                    ForEach(HabitWidgetSize.allCases, id: \.self) { size in
                                        Text(size.rawValue).tag(size)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            
                            HStack {
                                Text("Visual Style")
                                Spacer()
                                Picker("", selection: $habit.visualStyle) {
                                    ForEach(HabitVisualStyle.allCases, id: \.self) { style in
                                        Text(style.rawValue).tag(style)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                        
                        // Notes Section
                        SettingsSection(title: "Notes & Journey (\(habit.notes.count))") {
                            // Add note button
                            Button {
                                showAddNote = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Add Note")
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            
                            // Recent notes preview (show last 3)
                            if !habit.notes.isEmpty {
                                ForEach(habit.notes.prefix(3)) { note in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(note.content)
                                            .font(.subheadline)
                                            .lineLimit(2)
                                        
                                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                }
                                
                                // View all button if more than 3 notes
                                if habit.notes.count > 3 {
                                    Button {
                                        showNotesList = true
                                    } label: {
                                        HStack {
                                            Text("View All Notes")
                                            Spacer()
                                            Text("\(habit.notes.count)")
                                                .foregroundColor(.secondary)
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 12)
                                    }
                                    .background(Color(.secondarySystemGroupedBackground))
                                }
                            }
                        }
                        
                        // Actions Section
                        SettingsSection(title: "Actions") {
                            // Mark as Complete / Uncomplete button
                            Button {
                                if habit.isCompleted {
                                    habitManager.uncompleteHabit(habit)
                                } else {
                                    habitManager.completeHabit(habit)
                                }
                                if let updated = habitManager.habits.first(where: { $0.id == habit.id }) {
                                    habit = updated
                                }
                            } label: {
                                HStack {
                                    Image(systemName: habit.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.seal.fill")
                                    Text(habit.isCompleted ? "Mark as Active" : "Mark Goal Complete")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(habit.isCompleted ? .orange : .green)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            
                            Button {
                                habitManager.resetProgress(for: habit)
                                if let updated = habitManager.habits.first(where: { $0.id == habit.id }) {
                                    habit = updated
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text("Reset Progress")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.orange)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            
                            Button(role: .destructive) {
                                habitManager.deleteHabit(habit)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Habit")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        habitManager.updateHabit(habit)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteSheet(habitManager: habitManager, habit: habit)
            }
            .sheet(isPresented: $showNotesList) {
                NotesListSheet(habitManager: habitManager, habit: habit)
            }
            .onChange(of: showAddNote) { _, newValue in
                if !newValue {
                    // Refresh habit data after adding note
                    if let updated = habitManager.habits.first(where: { $0.id == habit.id }) {
                        habit = updated
                    }
                }
            }
            .onChange(of: showNotesList) { _, newValue in
                if !newValue {
                    // Refresh habit data after viewing/deleting notes
                    if let updated = habitManager.habits.first(where: { $0.id == habit.id }) {
                        habit = updated
                    }
                }
            }
        }
    }
}

// Helper views for settings
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 8)
            
            VStack(spacing: 1) {
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
        }
    }
}

struct SettingsRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Habits Section View
struct HabitsSection: View {
    @ObservedObject var habitManager: HabitManager
    @Binding var selectedHabit: Habit?
    @State private var showAddHabit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section Header
            HStack {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundColor(.green)
                Text("Habits")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                
                Button {
                    showAddHabit = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if habitManager.activeHabits.isEmpty {
                // Empty state
                Button {
                    showAddHabit = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.dashed")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text("Add Your First Habit")
                                .font(.subheadline.weight(.medium))
                            Text("Track streaks, countdowns & more")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .foregroundColor(.white.opacity(0.3))
                    )
                }
            } else {
                // Habit list with row-based layout
                ReorderableHabitList(
                    habitManager: habitManager,
                    selectedHabit: $selectedHabit
                )
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet(habitManager: habitManager)
        }
    }
}

// MARK: - Reorderable Habit List with Row Layout
struct ReorderableHabitList: View {
    @ObservedObject var habitManager: HabitManager
    @Binding var selectedHabit: Habit?
    
    var body: some View {
        let rows = buildRows(from: habitManager.activeHabits)
        
        VStack(spacing: 12) {
            ForEach(rows, id: \.id) { row in
                HStack(spacing: 12) {
                    ForEach(row.habits) { habit in
                        HabitCardWrapper(
                            habit: habit,
                            habitManager: habitManager,
                            selectedHabit: $selectedHabit
                        )
                    }
                    
                    // If single small widget in row, add invisible drop zone for the other half
                    if row.habits.count == 1 && row.habits[0].widgetSize == .half {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .dropDestination(for: String.self) { items, location in
                                // Drop into this slot = move after the lone small widget
                                if let droppedIDString = items.first,
                                   let droppedID = UUID(uuidString: droppedIDString),
                                   let fromIndex = habitManager.habits.firstIndex(where: { $0.id == droppedID }),
                                   let targetIndex = habitManager.habits.firstIndex(where: { $0.id == row.habits[0].id }) {
                                    let toIndex = targetIndex + 1
                                    if fromIndex != toIndex && fromIndex != targetIndex {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            habitManager.moveHabit(from: fromIndex, to: min(toIndex, habitManager.habits.count))
                                        }
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                    }
                                }
                                return true
                            } isTargeted: { _ in }
                    }
                }
            }
        }
    }
    
    // Build rows: small widgets can pair, others get own row
    private func buildRows(from habits: [Habit]) -> [HabitRowData] {
        var result: [HabitRowData] = []
        var pendingSmall: Habit? = nil
        
        for habit in habits {
            if habit.widgetSize == .half {
                if let first = pendingSmall {
                    result.append(HabitRowData(habits: [first, habit]))
                    pendingSmall = nil
                } else {
                    pendingSmall = habit
                }
            } else {
                if let small = pendingSmall {
                    result.append(HabitRowData(habits: [small]))
                    pendingSmall = nil
                }
                result.append(HabitRowData(habits: [habit]))
            }
        }
        
        if let small = pendingSmall {
            result.append(HabitRowData(habits: [small]))
        }
        
        return result
    }
}

// Helper struct for row grouping with stable ID
struct HabitRowData: Identifiable {
    let habits: [Habit]
    
    var id: String {
        habits.map { $0.id.uuidString }.joined(separator: "-")
    }
}

// MARK: - Habit Card Wrapper with Drag Support
struct HabitCardWrapper: View {
    let habit: Habit
    @ObservedObject var habitManager: HabitManager
    @Binding var selectedHabit: Habit?
    
    @State private var isTargeted = false
    @State private var showAddNote = false
    @State private var showNotesList = false
    
    // Pre-compute this to avoid context menu delay
    private var isTodayFilled: Bool {
        habit.manuallyFilledCells.contains(habit.currentCellIndex)
    }
    
    private var notesCount: Int {
        habit.notes.count
    }
    
    var body: some View {
        HabitCardContent(habit: habit)
            .frame(maxWidth: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green, lineWidth: 3)
                    .opacity(isTargeted ? 1 : 0)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                selectedHabit = habit
            }
            .draggable(habit.id.uuidString) {
                // Drag preview
                HabitCardContent(habit: habit)
                    .frame(width: 120, height: 80)
                    .opacity(0.8)
            }
            .dropDestination(for: String.self) { items, location in
                if let droppedIDString = items.first,
                   let droppedID = UUID(uuidString: droppedIDString),
                   droppedID != habit.id {
                    performMove(from: droppedID, to: habit.id)
                }
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
            .contextMenu {
                // Mark today (only for manual grid habits)
                if habit.updateMode == .manual && habit.visualStyle == .grid {
                    Button {
                        habitManager.incrementProgress(for: habit)
                    } label: {
                        Label(isTodayFilled ? "Unmark Today" : "Mark Today", systemImage: isTodayFilled ? "xmark.circle" : "checkmark.circle")
                    }
                }
                
                // Add Note - available for all habits
                Button {
                    showAddNote = true
                } label: {
                    Label("Add Note", systemImage: "square.and.pencil")
                }
                
                // View Notes - only if there are notes
                if notesCount > 0 {
                    Button {
                        showNotesList = true
                    } label: {
                        Label("View Notes (\(notesCount))", systemImage: "note.text")
                    }
                }
                
                Divider()
                
                Button(role: .destructive) {
                    habitManager.deleteHabit(habit)
                } label: {
                    Label("Delete Habit", systemImage: "trash")
                }
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteSheet(habitManager: habitManager, habit: habit)
            }
            .sheet(isPresented: $showNotesList) {
                NotesListSheet(habitManager: habitManager, habit: habit)
            }
    }
    
    private func performMove(from sourceID: UUID, to targetID: UUID) {
        guard let fromIndex = habitManager.habits.firstIndex(where: { $0.id == sourceID }),
              let toIndex = habitManager.habits.firstIndex(where: { $0.id == targetID }),
              fromIndex != toIndex else {
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            habitManager.moveHabit(from: fromIndex, to: toIndex)
        }
        
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
}

// MARK: - Habit Card Content (just the visual)
struct HabitCardContent: View {
    let habit: Habit
    
    var body: some View {
        Group {
            switch habit.visualStyle {
            case .grid:
                ContributionGridView(habit: habit)
            case .text:
                TextCounterView(habit: habit)
            case .bar:
                TimelineBarView(habit: habit)
            }
        }
    }
}

// MARK: - Tracker Home Screen
struct TrackerView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var showTimer: Bool
    @ObservedObject var stats: StatsManager
    @ObservedObject var settings: AppSettings
    @StateObject private var habitManager = HabitManager()
    
    private var orientationManager: OrientationManager { OrientationManager.shared }
    
    @State private var showHeader = false
    @State private var showLockInButton = false
    @State private var showStatsCard = false
    @State private var showHabitsSection = false
    @State private var selectedHabit: Habit?
    @State private var showCompletedGoals = false
    
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
                                .onTapGesture {
                                    showCompletedGoals = true
                                }
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
                                .onTapGesture {
                                    showCompletedGoals = true
                                }
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
                    StatsCard(stats: stats, habitManager: habitManager)
                        .opacity(showStatsCard ? 1 : 0)
                        .offset(y: showStatsCard ? 0 : 20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: showStatsCard)
                    
                    // Habits Section
                    HabitsSection(
                        habitManager: habitManager,
                        selectedHabit: $selectedHabit
                    )
                    .opacity(showHabitsSection ? 1 : 0)
                    .offset(y: showHabitsSection ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: showHabitsSection)
                    
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
        .sheet(item: $selectedHabit) { habit in
            HabitDetailSheet(habitManager: habitManager, habit: habit)
        }
        .fullScreenCover(isPresented: $showCompletedGoals) {
            CompletedGoalsView(habitManager: habitManager, isPresented: $showCompletedGoals)
        }
        .onAppear {
            orientationManager.lockToPortrait()
            
            showHeader = false
            showLockInButton = false
            showStatsCard = false
            showHabitsSection = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { showHeader = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { showLockInButton = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showStatsCard = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { showHabitsSection = true }
            
            // Check for any habits that have reached their goals
            habitManager.checkAndSendGoalNotifications()
        }
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    @ObservedObject var stats: StatsManager
    @ObservedObject var habitManager: HabitManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lock In Stats Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    Text("Lock In Stats")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
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
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // Habits Stats Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "target")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    Text("Habits Stats")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    StatItem(icon: "plus.circle.fill", value: "\(habitManager.totalHabitsCreated)", label: "Created", color: .blue)
                    StatItem(icon: "checkmark.seal.fill", value: "\(habitManager.totalHabitsCompleted)", label: "Completed", color: .green)
                    StatItem(icon: "arrow.clockwise", value: "\(habitManager.activeHabits.count)", label: "Active", color: .teal)
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

// MARK: - Completed Goals View
struct CompletedGoalsView: View {
    @ObservedObject var habitManager: HabitManager
    @Binding var isPresented: Bool
    @State private var selectedCompletedHabit: Habit?
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Same background as TrackerView
            TrackerBackground()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showContent = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isPresented = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Text("Completed Goals")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // Invisible spacer for balance
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
                
                if habitManager.completedHabits.isEmpty {
                    // Empty state
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow.opacity(0.5))
                        
                        Text("No Completed Goals Yet")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                        
                        Text("Complete your habits to see them here!")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    Spacer()
                } else {
                    // Completed habits list
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(habitManager.completedHabits) { habit in
                                CompletedHabitCard(habit: habit)
                                    .onTapGesture {
                                        selectedCompletedHabit = habit
                                    }
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 20)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .sheet(item: $selectedCompletedHabit) { habit in
            CompletedHabitDetailSheet(habitManager: habitManager, habit: habit)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Completed Habit Card
struct CompletedHabitCard: View {
    let habit: Habit
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(habit.color.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: habit.icon)
                    .font(.title3)
                    .foregroundColor(habit.color.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(habit.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    if let completedAt = habit.completedAt {
                        Label(completedAt.formatted(date: .abbreviated, time: .omitted), systemImage: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("\(habit.totalDurationCells) \(habit.cellUnit.pluralName)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
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
    }
}

// MARK: - Completed Habit Detail Sheet
struct CompletedHabitDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    @State var habit: Habit
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Completion Badge
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(habit.color.color.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.yellow)
                        }
                        
                        Text("Goal Completed!")
                            .font(.title2.weight(.bold))
                        
                        if let completedAt = habit.completedAt {
                            Text("Completed on \(completedAt.formatted(date: .long, time: .omitted))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // Grid Preview (for grid style habits)
                    if habit.visualStyle == .grid {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.12, blue: 0.3), Color(red: 0.2, green: 0.15, blue: 0.35)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            ContributionGridView(habit: habit, showFullGrid: true)
                                .padding(12)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Stats
                    VStack(spacing: 0) {
                        SettingsSection(title: "Journey Stats") {
                            SettingsRow(label: "Started", value: habit.startDate.formatted(date: .abbreviated, time: .omitted))
                            if let completedAt = habit.completedAt {
                                SettingsRow(label: "Completed", value: completedAt.formatted(date: .abbreviated, time: .omitted))
                                
                                let days = Calendar.current.dateComponents([.day], from: habit.startDate, to: completedAt).day ?? 0
                                SettingsRow(label: "Duration", value: "\(days) days")
                            }
                            SettingsRow(label: "Goal", value: "\(habit.totalDurationCells) \(habit.cellUnit.pluralName)")
                        }
                        
                        // Notes Section
                        SettingsSection(title: "My Notes & Journey (\(habit.notes.count))") {
                            if habit.notes.isEmpty {
                                Text("No notes recorded for this goal.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 12)
                                    .background(Color(.secondarySystemGroupedBackground))
                            } else {
                                ForEach(habit.notes) { note in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(note.content)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        
                                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    .background(Color(.secondarySystemGroupedBackground))
                                }
                            }
                        }
                        
                        // Actions
                        SettingsSection(title: "Actions") {
                            Button {
                                habitManager.uncompleteHabit(habit)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle")
                                    Text("Restore to Active")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .foregroundColor(.orange)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                            
                            Button(role: .destructive) {
                                habitManager.deleteHabit(habit)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Delete Permanently")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                            .background(Color(.secondarySystemGroupedBackground))
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(habit.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TrackerView(showTimer: .constant(false), stats: StatsManager(), settings: AppSettings())
}
