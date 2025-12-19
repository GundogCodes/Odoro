import SwiftUI
internal import Combine

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
    case text = "Text Counter"        // Day/week/hr/sec text
    case bar = "Timeline Bar"         // Filling bar
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
    
    // Progress tracking
    var currentValue: Int               // Current progress (cells filled for manual)
    var cycleCount: Int                 // How many times grid has cycled (for indefinite)
    
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
        self.currentValue = 0
        self.cycleCount = 0
        self.timeUnit = timeUnit
        self.color = color
        self.createdAt = Date()
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
    
    // Elapsed cells (time passed)
    var elapsedCells: Int {
        if updateMode == .manual {
            return currentValue
        }
        
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
    
    init() {
        load()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(habits) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
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
    
    func incrementProgress(for habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            let gridCapacity = h.gridDimensions.columns * h.gridDimensions.rows
            h.currentValue += 1
            
            // Handle cycling for indefinite habits
            if h.durationType == .indefinite && h.currentValue >= gridCapacity {
                h.currentValue = 0
                h.cycleCount += 1
            }
            
            updateHabit(h)
        }
    }
    
    func resetProgress(for habit: Habit) {
        if var h = habits.first(where: { $0.id == habit.id }) {
            h.currentValue = 0
            h.cycleCount = 0
            updateHabit(h)
        }
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
                isCountdown: habit.type == .countdown
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
        let elapsed = habit.elapsedCells
        
        let unitSuffix: String
        switch habit.cellUnit {
        case .day: unitSuffix = "d"
        case .week: unitSuffix = "w"
        case .month: unitSuffix = "mo"
        case .year: unitSuffix = "y"
        }
        
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
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            
            let totalHSpacing = spacing * CGFloat(columns - 1)
            let totalVSpacing = spacing * CGFloat(rows - 1)
            
            // Calculate cell size to fill available space (cells stretch to fill)
            let cellWidth = (availableWidth - totalHSpacing) / CGFloat(columns)
            let cellHeight = (availableHeight - totalVSpacing) / CGFloat(rows)
            
            VStack(spacing: spacing) {
                ForEach(Array(0..<rows), id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(Array(0..<columns), id: \.self) { col in
                            let cellIndex = (row * columns) + col
                            
                            if cellIndex < totalCells {
                                RoundedRectangle(cornerRadius: min(cellWidth, cellHeight) * 0.15)
                                    .fill(isCellFilled(at: cellIndex) ? color : Color.white.opacity(0.15))
                                    .frame(width: cellWidth, height: cellHeight)
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
    
    private func isCellFilled(at index: Int) -> Bool {
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
            }
            
            Spacer(minLength: 0)
            
            if isSmall {
                // Small: Single large number centered
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
                // Medium/Large: Multiple time components
                HStack(spacing: 12) {
                    ForEach(timeComponents, id: \.label) { component in
                        VStack(spacing: 4) {
                            Text(component.value)
                                .font(.system(size: isLarge ? 32 : 28, weight: .bold, design: .rounded))
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
    
    private var timeInterval: TimeInterval {
        if habit.type == .countdown {
            return (habit.targetDate ?? Date()).timeIntervalSince(currentTime)
        } else {
            return currentTime.timeIntervalSince(habit.startDate)
        }
    }
    
    private var progressToTarget: CGFloat {
        let filled = habit.filledCells(at: currentTime)
        let total = habit.totalCells
        guard total > 0 else { return 0 }
        return CGFloat(min(max(Double(filled) / Double(total), 0), 1))
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
    
    private var timeComponents: [TimeComponent] {
        let interval = abs(timeInterval)
        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
        
        if days > 0 {
            return [
                TimeComponent(value: "\(days)", label: "days"),
                TimeComponent(value: String(format: "%02d", hours), label: "hrs"),
                TimeComponent(value: String(format: "%02d", minutes), label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
            ]
        } else {
            return [
                TimeComponent(value: String(format: "%02d", hours), label: "hours"),
                TimeComponent(value: String(format: "%02d", minutes), label: "min"),
                TimeComponent(value: String(format: "%02d", seconds), label: "sec")
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
                Text(progressText)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer(minLength: 0)
            
            // Main time display
            Text(mainTimeDisplay)
                .font(.system(size: isSmall ? 28 : (isLarge ? 36 : 32), weight: .bold, design: .rounded))
                .foregroundStyle(habit.color.gradient)
                .frame(maxWidth: .infinity, alignment: isSmall ? .center : .leading)
            
            Spacer(minLength: 0)
            
            // Progress bar - always fills from left
            // For countdown: starts full, decreases over time
            // For count up: starts empty, increases over time
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: isSmall ? 6 : 10)
                    .fill(.white.opacity(0.15))
                
                // Fill
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: isSmall ? 6 : 10)
                        .fill(habit.color.gradient)
                        .frame(width: geo.size.width * progress)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: isSmall ? 16 : 24)
            
            if !isSmall {
                // Time labels
                HStack {
                    Text(startLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    Text(endLabel)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
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
    
    private var progress: CGFloat {
        let elapsed = habit.elapsedCells
        let total = habit.totalDurationCells
        
        guard total > 0 else { return 0 }
        
        let rawProgress = CGFloat(min(max(Double(elapsed) / Double(total), 0), 1))
        
        // For countdown: start full (1.0) and decrease to empty (0.0)
        // For count up: start empty (0.0) and increase to full (1.0)
        if habit.type == .countdown {
            return 1.0 - rawProgress
        } else {
            return rawProgress
        }
    }
    
    private var progressText: String {
        // For countdown show remaining %, for count up show elapsed %
        if habit.type == .countdown {
            String(format: "%.1f%% left", progress * 100)
        } else {
            String(format: "%.1f%%", progress * 100)
        }
    }
    
    private var startLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: habit.startDate)
    }
    
    private var endLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if let target = habit.targetDate {
            return formatter.string(from: target)
        }
        
        // Calculate end date from duration
        let calendar = Calendar.current
        let endDate: Date?
        
        switch habit.cellUnit {
        case .day:
            endDate = calendar.date(byAdding: .day, value: habit.totalDurationCells, to: habit.startDate)
        case .week:
            endDate = calendar.date(byAdding: .weekOfYear, value: habit.totalDurationCells, to: habit.startDate)
        case .month:
            endDate = calendar.date(byAdding: .month, value: habit.totalDurationCells, to: habit.startDate)
        case .year:
            endDate = calendar.date(byAdding: .year, value: habit.totalDurationCells, to: habit.startDate)
        }
        
        if let end = endDate {
            return formatter.string(from: end)
        }
        
        return "End"
    }
    
    private var mainTimeDisplay: String {
        let interval = abs(habit.type == .countdown ?
                         (habit.targetDate ?? Date()).timeIntervalSince(currentTime) :
                            currentTime.timeIntervalSince(habit.startDate))
        
        let days = Int(interval / 86400)
        let hours = Int(interval.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            let seconds = Int(interval.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Habit Card (Container)
struct HabitCard: View {
    let habit: Habit
    @ObservedObject var habitManager: HabitManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(.plain)
        .contextMenu {
            // Manual progress only for grid style
            if habit.updateMode == .manual && habit.visualStyle == .grid {
                Button {
                    habitManager.incrementProgress(for: habit)
                } label: {
                    Label("Add Progress", systemImage: "plus.circle")
                }
            }
            
            Button {
                habitManager.resetProgress(for: habit)
            } label: {
                Label("Reset Progress", systemImage: "arrow.counterclockwise")
            }
            
            Button(role: .destructive) {
                habitManager.deleteHabit(habit)
            } label: {
                Label("Delete Habit", systemImage: "trash")
            }
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
    
    // Display settings
    @State private var timeUnit: HabitTimeUnit = .days
    @State private var color: HabitColor = .blue
    
    @State private var currentPreviewPage = 0
    
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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Style Preview")
                            .font(.headline)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        TabView(selection: $currentPreviewPage) {
                            ForEach(Array(HabitVisualStyle.allCases.enumerated()), id: \.element) { index, style in
                                PreviewCard(style: style, habit: previewHabit(for: style))
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .always))
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
                                // Duration type (no indefinite for bar)
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
                                
                                // Time unit for bar
                                HStack {
                                    Text("Time Unit")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Picker("Time Unit", selection: $cellUnit) {
                                        ForEach(CellUnit.allCases, id: \.self) { unit in
                                            Text(unit.pluralName.capitalized).tag(unit)
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
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Text Counter Settings
                    if visualStyle == .text {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Display Settings")
                                .font(.headline)
                            
                            HStack {
                                Text("Show Time As")
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
            durationType: style == .bar ? barDurationType.toGridDurationType : durationType,
            customDuration: customDuration,
            targetDate: (durationType == .toTargetDate || barDurationType == .toTargetDate) ? targetDate : nil,
            timeUnit: timeUnit,
            color: color
        )
        
        // Set sample progress for preview (about 1/3 filled)
        habit.currentValue = habit.totalDurationCells / 3
        
        return habit
    }
    
    private func addHabit() {
        let finalDurationType = visualStyle == .bar ? barDurationType.toGridDurationType : durationType
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
        VStack {
            ZStack {
                // Dark background to match tracker view
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.12, blue: 0.3), Color(red: 0.2, green: 0.15, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Group {
                    switch style {
                    case .grid:
                        ContributionGridView(habit: habit)
                    case .text:
                        TextCounterView(habit: habit)
                    case .bar:
                        TimelineBarView(habit: habit)
                    }
                }
                .padding(8)
            }
            
            Text(style.rawValue)
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Habit Detail/Edit Sheet
struct HabitDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var habitManager: HabitManager
    @State var habit: Habit
    
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
                                    Text("Current Progress")
                                    Spacer()
                                    Stepper("\(habit.currentValue)", value: $habit.currentValue, in: 0...habit.totalDurationCells)
                                        .labelsHidden()
                                    Text("\(habit.currentValue)")
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
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
                                        Image(systemName: "plus.circle.fill")
                                        Text("Add Progress")
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
                        
                        // Actions Section
                        SettingsSection(title: "Actions") {
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
                    .font(.subheadline)
                    .foregroundColor(.green)
                Text("Habits")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Spacer()
                
                Button {
                    showAddHabit = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            if habitManager.habits.isEmpty {
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
                // Habits Layout - respecting widget sizes
                VStack(spacing: 12) {
                    ForEach(habitRows, id: \.0) { rowIndex, row in
                        HStack(spacing: 12) {
                            ForEach(row) { habit in
                                HabitCard(habit: habit, habitManager: habitManager) {
                                    selectedHabit = habit
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // If only one half-width in row, add spacer to keep it half
                            if row.count == 1 && row[0].widgetSize == .half {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitSheet(habitManager: habitManager)
        }
    }
    
    // Organize habits into rows: full/medium get own row, half-width pair up
    private var habitRows: [(Int, [Habit])] {
        var rows: [[Habit]] = []
        var currentHalfRow: [Habit] = []
        
        for habit in habitManager.habits {
            if habit.widgetSize == .half {
                // Half width - accumulate and pair
                currentHalfRow.append(habit)
                if currentHalfRow.count == 2 {
                    rows.append(currentHalfRow)
                    currentHalfRow = []
                }
            } else {
                // Full or Medium width - flush pending halfs, then own row
                if !currentHalfRow.isEmpty {
                    rows.append(currentHalfRow)
                    currentHalfRow = []
                }
                rows.append([habit])
            }
        }
        
        // Don't forget remaining half-width habit
        if !currentHalfRow.isEmpty {
            rows.append(currentHalfRow)
        }
        
        return rows.enumerated().map { ($0.offset, $0.element) }
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
                    
                    // Habits Section
                    HabitsSection(habitManager: habitManager, selectedHabit: $selectedHabit)
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
