//
//  HabitWidgets.swift
//  OdoroWidgetExtension
//
//  Home screen widgets for habit tracking
//  Add this file to WIDGET EXTENSION target ONLY
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habit: Habit?
    let widgetFamily: WidgetFamily
}

// MARK: - Timeline Provider with Intent
struct HabitWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = HabitWidgetEntry
    typealias Intent = SelectHabitIntent
    
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: Date(), habit: sampleHabit(for: context.family), widgetFamily: context.family)
    }
    
    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitWidgetEntry {
        let habit = getHabit(for: configuration, family: context.family)
        return HabitWidgetEntry(date: Date(), habit: habit, widgetFamily: context.family)
    }
    
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
        let habit = getHabit(for: configuration, family: context.family)
        let entry = HabitWidgetEntry(date: Date(), habit: habit, widgetFamily: context.family)
        
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func getHabit(for configuration: SelectHabitIntent, family: WidgetFamily) -> Habit? {
        let habits = HabitDataStore.shared.activeHabits
        
        // If user selected a specific habit, use that
        if let selectedHabitID = configuration.habit?.id,
           let habit = habits.first(where: { $0.id.uuidString == selectedHabitID }) {
            return habit
        }
        
        // Otherwise return first habit
        return habits.first
    }
    
    private func sampleHabit(for family: WidgetFamily) -> Habit {
        let size: HabitWidgetSize = {
            switch family {
            case .systemSmall: return .half
            case .systemMedium: return .fullMedium
            case .systemLarge: return .full
            default: return .full
            }
        }()
        
        return Habit(
            id: UUID(),
            name: "Sample Habit",
            icon: "target",
            type: .countUp,
            updateMode: .auto,
            visualStyle: .grid,
            widgetSize: size,
            cellUnit: .day,
            durationType: .customRange,
            customDuration: 30,
            targetDate: nil,
            textCounterDuration: 30,
            timelineTickUnit: .day,
            timelineDuration: 30,
            currentValue: 0,
            cycleCount: 0,
            manuallyFilledCells: [],
            notes: [],
            isCompleted: false,
            completedAt: nil,
            timeUnit: .days,
            color: .purple,
            createdAt: Calendar.current.date(byAdding: .day, value: -12, to: Date()) ?? Date()
        )
    }
}

// MARK: - Widget View
struct HabitWidgetView: View {
    let entry: HabitWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        Group {
            if let habit = entry.habit {
                switch habit.visualStyle {
                case .grid:
                    WidgetGridView(habit: habit, family: family)
                case .text:
                    WidgetTextCounterView(habit: habit, family: family)
                case .bar:
                    WidgetTimelineBarView(habit: habit, family: family)
                }
            } else {
                EmptyWidgetView()
            }
        }
    }
}

// MARK: - Widget Background (Wavy Design)
struct WidgetBackground: View {
    var body: some View {
        ZStack {
            // Base gradient matching your app
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.06, blue: 0.15),
                    Color(red: 0.12, green: 0.08, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Subtle wave overlay
            GeometryReader { geo in
                WaveShape(amplitude: 20, frequency: 2, phase: 0)
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.15), .blue.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: geo.size.height * 0.3)
                
                WaveShape(amplitude: 15, frequency: 1.5, phase: 0.5)
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.1), .purple.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: geo.size.height * 0.5)
            }
        }
    }
}

struct WaveShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: 0, y: height))
        
        for x in stride(from: 0, through: width, by: 1) {
            let relativeX = x / width
            let sine = sin((relativeX * frequency * .pi * 2) + (phase * .pi * 2))
            let y = amplitude * sine + height * 0.3
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Empty State (with debug)
struct EmptyWidgetView: View {
    var body: some View {
        let result = debugLoadHabits()
        
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.purple)
            
            if let error = result.error {
                Text("Error:")
                    .font(.caption2)
                    .foregroundColor(.red)
                Text(error)
                    .font(.system(size: 8))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
            } else {
                Text("Total: \(result.count)")
                    .font(.caption)
                    .foregroundColor(.white)
                Text("Active: \(result.active)")
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }
    
    func debugLoadHabits() -> (count: Int, active: Int, error: String?) {
        guard let userDefaults = UserDefaults(suiteName: "group.com.gunisharma.com") else {
            return (0, 0, "No App Group")
        }
        
        guard let data = userDefaults.data(forKey: "sharedHabits") else {
            return (0, 0, "No data")
        }
        
        do {
            let habits = try JSONDecoder().decode([Habit].self, from: data)
            let active = habits.filter { !$0.isCompleted }.count
            return (habits.count, active, nil)
        } catch let DecodingError.keyNotFound(key, _) {
            return (0, 0, "Missing: \(key.stringValue)")
        } catch let DecodingError.typeMismatch(type, context) {
            let path = context.codingPath.map { $0.stringValue }.joined(separator: ".")
            return (0, 0, "Type \(type) at \(path)")
        } catch {
            return (0, 0, "\(error)")
        }
    }
}

// MARK: - Grid Widget View
struct WidgetGridView: View {
    let habit: Habit
    let family: WidgetFamily
    
    private var isSmall: Bool { family == .systemSmall }
    private var dimensions: (columns: Int, rows: Int) { habit.gridDimensions }
    
    private var filledCellsForDisplay: Int {
        let filled = habit.filledCells()
        if habit.type == .countdown {
            return max(0, habit.totalCells - filled)
        }
        return filled
    }
    
    private var progressLabel: String {
        let pageInfo = habit.gridPageInfo
        let totalDuration = habit.totalDurationCells
        
        let unitSuffix: String = {
            switch habit.cellUnit {
            case .day: return "d"
            case .week: return "w"
            case .month: return "mo"
            case .year: return "y"
            }
        }()
        
        if habit.updateMode == .manual {
            let filledCount = habit.manuallyFilledCells.count
            if habit.durationType == .indefinite {
                let cycleInfo = habit.cycleCount > 0 ? " (×\(habit.cycleCount + 1))" : ""
                return "\(filledCount)/\(pageInfo.cellsInCurrentPage)\(cycleInfo)"
            }
            return "\(filledCount)/\(totalDuration)"
        }
        
        let elapsed = habit.elapsedCells
        if habit.durationType == .indefinite {
            let cycleInfo = habit.cycleCount > 0 ? " (×\(habit.cycleCount + 1))" : ""
            return "\(pageInfo.filledInCurrentPage)/\(pageInfo.cellsInCurrentPage)\(cycleInfo)"
        }
        
        if pageInfo.totalPages > 1 {
            return "\(elapsed)/\(totalDuration)\(unitSuffix)"
        }
        return "\(elapsed)/\(totalDuration)\(unitSuffix)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 4 : 6) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(progressLabel)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Grid - takes all remaining space
            WidgetGridContent(
                columns: dimensions.columns,
                rows: dimensions.rows,
                filledCells: filledCellsForDisplay,
                totalCells: habit.totalCells,
                color: habit.color.color,
                spacing: isSmall ? 2 : 3,
                isCountdown: habit.type == .countdown,
                isManualMode: habit.updateMode == .manual,
                manuallyFilledCells: habit.manuallyFilledCells,
                currentCellIndex: habit.currentCellIndex
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WidgetGridContent: View {
    let columns: Int
    let rows: Int
    let filledCells: Int
    let totalCells: Int
    let color: Color
    let spacing: CGFloat
    let isCountdown: Bool
    let isManualMode: Bool
    let manuallyFilledCells: Set<Int>
    let currentCellIndex: Int
    
    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width
            let availableHeight = geo.size.height
            let totalHSpacing = spacing * CGFloat(columns - 1)
            let totalVSpacing = spacing * CGFloat(rows - 1)
            let cellWidth = (availableWidth - totalHSpacing) / CGFloat(columns)
            let cellHeight = (availableHeight - totalVSpacing) / CGFloat(rows)
            
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { col in
                            let cellIndex = (row * columns) + col
                            
                            if cellIndex < totalCells {
                                RoundedRectangle(cornerRadius: min(cellWidth, cellHeight) * 0.15)
                                    .fill(cellColor(at: cellIndex))
                                    .frame(width: cellWidth, height: cellHeight)
                            } else {
                                Color.clear
                                    .frame(width: cellWidth, height: cellHeight)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func cellColor(at index: Int) -> Color {
        if isManualMode {
            if manuallyFilledCells.contains(index) {
                return color
            } else if index == currentCellIndex {
                return Color.white.opacity(0.25)
            } else if index > currentCellIndex {
                return Color.white.opacity(0.1)
            } else {
                return Color.white.opacity(0.15)
            }
        } else {
            if isCellFilled(at: index) {
                return color
            } else {
                return Color.white.opacity(0.15)
            }
        }
    }
    
    private func isCellFilled(at index: Int) -> Bool {
        if isCountdown {
            let emptyCount = totalCells - filledCells
            return index >= emptyCount && index < totalCells
        } else {
            return index < filledCells
        }
    }
}

// MARK: - Text Counter Widget View
struct WidgetTextCounterView: View {
    let habit: Habit
    let family: WidgetFamily
    
    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate { return target }
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
        let now = Date()
        if habit.type == .countdown {
            return calculatedTargetDate.timeIntervalSince(now)
        } else {
            return now.timeIntervalSince(habit.startDate)
        }
    }
    
    private var progressToTarget: CGFloat {
        let now = Date()
        let totalInterval = calculatedTargetDate.timeIntervalSince(habit.startDate)
        guard totalInterval > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(habit.startDate)
        let progress = CGFloat(min(max(elapsed / totalInterval, 0), 1))
        return habit.type == .countdown ? 1.0 - progress : progress
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
            
            // Counter display
            VStack(spacing: 4) {
                Text(primaryValue)
                    .font(.system(size: isSmall ? 28 : (isLarge ? 44 : 36), weight: .bold, design: .rounded))
                    .foregroundStyle(habit.color.gradient)
                Text(primaryLabel)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            
            Spacer(minLength: 0)
            
            // Progress bar
            if habit.durationType != .indefinite {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.1))
                        .frame(height: 4)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(habit.color.gradient)
                            .frame(width: geo.size.width * progressToTarget)
                    }
                    .frame(height: 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Timeline Bar Widget View
struct WidgetTimelineBarView: View {
    let habit: Habit
    let family: WidgetFamily
    
    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate { return target }
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
    
    private var totalTicks: Int {
        habit.timelineDuration
    }
    
    private var elapsedTicks: Int {
        let calendar = Calendar.current
        let now = Date()
        switch habit.timelineTickUnit {
        case .minute:
            return max(0, min(totalTicks, calendar.dateComponents([.minute], from: habit.startDate, to: now).minute ?? 0))
        case .hour:
            return max(0, min(totalTicks, calendar.dateComponents([.hour], from: habit.startDate, to: now).hour ?? 0))
        case .day:
            return max(0, min(totalTicks, calendar.dateComponents([.day], from: habit.startDate, to: now).day ?? 0))
        case .week:
            let days = calendar.dateComponents([.day], from: habit.startDate, to: now).day ?? 0
            return max(0, min(totalTicks, days / 7))
        case .month:
            return max(0, min(totalTicks, calendar.dateComponents([.month], from: habit.startDate, to: now).month ?? 0))
        case .year:
            return max(0, min(totalTicks, calendar.dateComponents([.year], from: habit.startDate, to: now).year ?? 0))
        }
    }
    
    private var progress: CGFloat {
        guard totalTicks > 0 else { return 0 }
        return CGFloat(elapsedTicks) / CGFloat(totalTicks)
    }
    
    private var mainTimeDisplay: String {
        let remaining = totalTicks - elapsedTicks
        let displayValue = habit.type == .countdown ? remaining : elapsedTicks
        
        switch habit.timelineTickUnit {
        case .minute:
            let hrs = displayValue / 60
            let mins = displayValue % 60
            return hrs > 0 ? "\(hrs)h \(mins)m" : "\(mins)m"
        case .hour:
            let days = displayValue / 24
            let hrs = displayValue % 24
            return days > 0 ? "\(days)d \(hrs)h" : "\(hrs)h"
        case .day:
            let weeks = displayValue / 7
            let days = displayValue % 7
            return weeks > 0 ? "\(weeks)w \(days)d" : "\(days) days"
        case .week:
            let months = displayValue / 4
            let weeks = displayValue % 4
            return months > 0 ? "\(months)mo \(weeks)w" : "\(weeks) weeks"
        case .month:
            let years = displayValue / 12
            let months = displayValue % 12
            return years > 0 ? "\(years)y \(months)mo" : "\(months) months"
        case .year:
            return "\(displayValue) years"
        }
    }
    
    private var tickCount: Int {
        isSmall ? 8 : (isLarge ? 20 : 15)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            
            Spacer(minLength: 0)
            
            // Main time display
            Text(mainTimeDisplay)
                .font(.system(size: isSmall ? 20 : (isLarge ? 32 : 26), weight: .bold, design: .rounded))
                .foregroundStyle(habit.color.gradient)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Spacer(minLength: 0)
            
            // Timeline ticks
            HStack(spacing: isSmall ? 2 : 3) {
                ForEach(0..<tickCount, id: \.self) { index in
                    let tickProgress = CGFloat(index) / CGFloat(tickCount - 1)
                    let isFilled = habit.type == .countdown
                        ? tickProgress >= (1.0 - progress)
                        : tickProgress <= progress
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isFilled ? habit.color.color : Color.white.opacity(0.15))
                        .frame(height: isSmall ? 4 : 6)
                }
            }
            
            // Labels
            HStack {
                Text(habit.startDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(calculatedTargetDate.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget Configuration
struct HabitWidget: Widget {
    let kind: String = "HabitWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: SelectHabitIntent.self,
            provider: HabitWidgetProvider()
        ) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground()
                }
        }
        .configurationDisplayName("Habit Tracker")
        .description("Track your habit progress on your home screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview("Small", as: .systemSmall) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry(date: Date(), habit: nil, widgetFamily: .systemSmall)
}

#Preview("Medium", as: .systemMedium) {
    HabitWidget()
} timeline: {
    HabitWidgetEntry(date: Date(), habit: nil, widgetFamily: .systemMedium)
}
