//
//  HabitWidgets.swift
//  OdoroWidgetExtension
//
//  Home screen widgets matching app aesthetic
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Entry
struct HabitWidgetEntry: TimelineEntry {
    let date: Date
    let habit: Habit?
}

// MARK: - Timeline Provider with Intent
struct HabitWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = HabitWidgetEntry
    typealias Intent = SelectHabitIntent
    
    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: Date(), habit: nil)
    }
    
    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitWidgetEntry {
        let habit = getHabit(for: configuration)
        return HabitWidgetEntry(date: Date(), habit: habit)
    }
    
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
        let habit = getHabit(for: configuration)
        let entry = HabitWidgetEntry(date: Date(), habit: habit)
        
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func getHabit(for configuration: SelectHabitIntent) -> Habit? {
        let habits = HabitDataStore.shared.activeHabits
        
        if let selectedHabitID = configuration.habit?.id,
           let habit = habits.first(where: { $0.id.uuidString == selectedHabitID }) {
            return habit
        }
        return habits.first
    }
}

// MARK: - Widget View
struct HabitWidgetView: View {
    let entry: HabitWidgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Group {
            if let habit = entry.habit {
                switch habit.visualStyle {
                case .grid:
                    WidgetGridView(habit: habit, family: family)
                case .bar:
                    WidgetTimelineBarView(habit: habit, family: family)
                case .text:
                    WidgetTextCounterView(habit: habit, family: family)
                }
            } else {
                EmptyWidgetView()
            }
        }
    }
}

// MARK: - Empty State
struct EmptyWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("Add a habit")
                .font(.subheadline.weight(.medium))
                .foregroundColor(colorScheme == .dark ? .white : .primary)
            
            Text("to see progress")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Grid Widget View
struct WidgetGridView: View {
    let habit: Habit
    let family: WidgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    private var dimensions: (columns: Int, rows: Int) { habit.gridDimensions }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    // Gold colors for goal cell
    private let goldColor = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldGradient = LinearGradient(
        colors: [
            Color(red: 1.0, green: 0.9, blue: 0.4),
            Color(red: 1.0, green: 0.75, blue: 0.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    private var filledCellsForDisplay: Int {
        if habit.updateMode == .manual {
            return habit.manuallyFilledCells.count
        }
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
            return "\(filledCount)/\(totalDuration)"
        }
        
        let elapsed = habit.elapsedCells
        return "\(elapsed)/\(totalDuration)\(unitSuffix)"
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
                    .foregroundColor(textColor)
                    .lineLimit(1)
                Spacer()
                Text(progressLabel)
                    .font(isSmall ? .caption2 : .caption)
                    .foregroundColor(textColor.opacity(0.7))
            }
            
            // Grid
            GeometryReader { geo in
                let spacing: CGFloat = isSmall ? 3 : 4
                let cols = dimensions.columns
                let rows = dimensions.rows
                let totalHSpacing = spacing * CGFloat(cols - 1)
                let totalVSpacing = spacing * CGFloat(rows - 1)
                let cellWidth = (geo.size.width - totalHSpacing) / CGFloat(cols)
                let cellHeight = (geo.size.height - totalVSpacing) / CGFloat(rows)
                let cornerRadius = min(cellWidth, cellHeight) * 0.15
                
                VStack(spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<cols, id: \.self) { col in
                                let cellIndex = (row * cols) + col
                                
                                if cellIndex < habit.totalCells {
                                    // Check if this is the goal cell
                                    if cellIndex == habit.goalCellIndexInCurrentPage {
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
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
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
                .shadow(color: goldColor.opacity(0.5), radius: 2, x: 0, y: 0)
                .frame(width: width, height: height)
        } else {
            // Gold outline when unfilled
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(goldGradient, lineWidth: 1.5)
                )
                .frame(width: width, height: height)
        }
    }
    
    private func cellColor(at index: Int) -> Color {
        let emptyColor = colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1)
        
        if habit.updateMode == .manual {
            if habit.manuallyFilledCells.contains(index) {
                return habit.color.color
            }
            return emptyColor
        } else {
            let isFilled = isCellFilled(at: index)
            return isFilled ? habit.color.color : emptyColor
        }
    }
    
    private func isCellFilled(at index: Int) -> Bool {
        if habit.updateMode == .manual {
            return habit.manuallyFilledCells.contains(index)
        }
        
        if habit.type == .countdown {
            let emptyCount = habit.totalCells - filledCellsForDisplay
            return index >= emptyCount && index < habit.totalCells
        } else {
            return index < filledCellsForDisplay
        }
    }
}

// MARK: - Text Counter Widget View (matches app)
struct WidgetTextCounterView: View {
    let habit: Habit
    let family: WidgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate { return target }
        let calendar = Calendar.current
        let duration = habit.textCounterDuration
        
        switch habit.timeUnit {
        case .seconds: return calendar.date(byAdding: .second, value: duration, to: habit.startDate) ?? habit.startDate
        case .minutes: return calendar.date(byAdding: .minute, value: duration, to: habit.startDate) ?? habit.startDate
        case .hours: return calendar.date(byAdding: .hour, value: duration, to: habit.startDate) ?? habit.startDate
        case .days: return calendar.date(byAdding: .day, value: duration, to: habit.startDate) ?? habit.startDate
        case .weeks: return calendar.date(byAdding: .weekOfYear, value: duration, to: habit.startDate) ?? habit.startDate
        case .months: return calendar.date(byAdding: .month, value: duration, to: habit.startDate) ?? habit.startDate
        case .years: return calendar.date(byAdding: .year, value: duration, to: habit.startDate) ?? habit.startDate
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
        let totalInterval = calculatedTargetDate.timeIntervalSince(habit.startDate)
        guard totalInterval > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(habit.startDate)
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
    
    // Time components for medium/large widgets
    private var timeComponents: [(value: String, label: String)] {
        let interval = abs(timeInterval)
        let totalSeconds = Int(interval)
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let totalHours = totalMinutes / 60
        let hours = totalHours % 24
        let totalDays = totalHours / 24
        
        switch habit.timeUnit {
        case .seconds:
            return [("\(totalSeconds)", "sec")]
        case .minutes:
            return [("\(totalMinutes)", "min"), (String(format: "%02d", seconds), "sec")]
        case .hours:
            return [("\(totalHours)", "hrs"), (String(format: "%02d", minutes), "min"), (String(format: "%02d", seconds), "sec")]
        case .days:
            return [("\(totalDays)", "days"), (String(format: "%02d", hours), "hrs"), (String(format: "%02d", minutes), "min")]
        case .weeks:
            let weeks = totalDays / 7
            let days = totalDays % 7
            return [("\(weeks)", "wks"), ("\(days)", "days"), (String(format: "%02d", hours), "hrs")]
        case .months:
            let months = totalDays / 30
            let days = totalDays % 30
            return [("\(months)", "mos"), ("\(days)", "days"), (String(format: "%02d", hours), "hrs")]
        case .years:
            let years = totalDays / 365
            let months = (totalDays % 365) / 30
            let days = (totalDays % 365) % 30
            return [("\(years)", "yrs"), ("\(months)", "mos"), ("\(days)", "days")]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 8 : 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                Spacer()
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(textColor.opacity(0.5))
            }
            
            Spacer(minLength: 0)
            
            if isSmall {
                // Small: Show primary unit centered
                VStack(spacing: 4) {
                    Text(primaryValue)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(habit.color.gradient)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text(primaryLabel)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            } else {
                // Medium/Large: Multiple time components
                HStack(spacing: isLarge ? 16 : 10) {
                    ForEach(timeComponents.prefix(isLarge ? 4 : 3), id: \.label) { component in
                        VStack(spacing: 4) {
                            Text(component.value)
                                .font(.system(size: isLarge ? 32 : 26, weight: .bold, design: .rounded))
                                .foregroundStyle(habit.color.gradient)
                            Text(component.label)
                                .font(.caption2)
                                .foregroundColor(textColor.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Progress indicator
            if habit.durationType != .indefinite {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.1))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(habit.color.gradient)
                            .frame(width: geo.size.width * progressToTarget)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(12)
    }
}

// MARK: - Timeline Bar Widget View (matches app with vertical ticks)
struct WidgetTimelineBarView: View {
    let habit: Habit
    let family: WidgetFamily
    @Environment(\.colorScheme) var colorScheme
    
    private var isSmall: Bool { family == .systemSmall }
    private var isLarge: Bool { family == .systemLarge }
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .primary
    }
    
    private var calculatedTargetDate: Date {
        if let target = habit.targetDate { return target }
        let calendar = Calendar.current
        let duration = habit.timelineDuration
        
        switch habit.timelineTickUnit {
        case .minute: return calendar.date(byAdding: .minute, value: duration, to: habit.startDate) ?? habit.startDate
        case .hour: return calendar.date(byAdding: .hour, value: duration, to: habit.startDate) ?? habit.startDate
        case .day: return calendar.date(byAdding: .day, value: duration, to: habit.startDate) ?? habit.startDate
        case .week: return calendar.date(byAdding: .weekOfYear, value: duration, to: habit.startDate) ?? habit.startDate
        case .month: return calendar.date(byAdding: .month, value: duration, to: habit.startDate) ?? habit.startDate
        case .year: return calendar.date(byAdding: .year, value: duration, to: habit.startDate) ?? habit.startDate
        }
    }
    
    private var totalTicks: Int { habit.timelineDuration }
    
    private var elapsedTicks: Int {
        let calendar = Calendar.current
        let now = Date()
        var ticks: Int
        switch habit.timelineTickUnit {
        case .minute: ticks = calendar.dateComponents([.minute], from: habit.startDate, to: now).minute ?? 0
        case .hour: ticks = calendar.dateComponents([.hour], from: habit.startDate, to: now).hour ?? 0
        case .day: ticks = calendar.dateComponents([.day], from: habit.startDate, to: now).day ?? 0
        case .week:
            let days = calendar.dateComponents([.day], from: habit.startDate, to: now).day ?? 0
            ticks = days / 7
        case .month: ticks = calendar.dateComponents([.month], from: habit.startDate, to: now).month ?? 0
        case .year: ticks = calendar.dateComponents([.year], from: habit.startDate, to: now).year ?? 0
        }
        return max(0, min(ticks, totalTicks))
    }
    
    private var progress: CGFloat {
        guard totalTicks > 0 else { return 0 }
        let rawProgress = CGFloat(elapsedTicks) / CGFloat(totalTicks)
        let clampedProgress = min(max(rawProgress, 0), 1)
        return habit.type == .countdown ? 1.0 - clampedProgress : clampedProgress
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
    
    private var progressText: String {
        if habit.type == .countdown {
            return String(format: "%.1f%% remaining", progress * 100)
        } else {
            return String(format: "%.1f%% complete", (1 - progress) * 100)
        }
    }
    
    private var maxVisibleTicks: Int {
        switch family {
        case .systemSmall: return 10
        case .systemMedium: return 20
        case .systemLarge: return 30
        default: return 20
        }
    }
    
    private func isTickFilled(index: Int, total: Int) -> Bool {
        guard total > 0 else { return false }
        let tickProgress = CGFloat(index) / CGFloat(total)
        if habit.type == .countdown {
            return tickProgress >= (1.0 - progress)
        } else {
            return tickProgress <= progress
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmall ? 6 : 10) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: habit.icon)
                    .font(isSmall ? .caption : .subheadline)
                    .foregroundColor(habit.color.color)
                Text(habit.name)
                    .font(isSmall ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                Spacer()
                Text(habit.type == .countdown ? "remaining" : "elapsed")
                    .font(.caption2)
                    .foregroundColor(textColor.opacity(0.5))
            }
            
            // Time display
            Text(mainTimeDisplay)
                .font(.system(size: isSmall ? 20 : (isLarge ? 28 : 24), weight: .bold, design: .rounded))
                .foregroundStyle(habit.color.gradient)
                .frame(maxWidth: .infinity, alignment: isSmall ? .center : .leading)
            
            // Progress info (not on small)
            if !isSmall {
                HStack {
                    Text(progressText)
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                    Spacer()
                    Text("\(elapsedTicks) / \(totalTicks) \(habit.timelineTickUnit.displayName.lowercased())")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            
            Spacer(minLength: 0)
            
            // Timeline with vertical ticks (like the app)
            GeometryReader { geo in
                let tickCount = min(totalTicks, maxVisibleTicks)
                let tickSpacing = tickCount > 1 ? geo.size.width / CGFloat(tickCount) : geo.size.width
                let barHeight: CGFloat = isLarge ? 8 : 6
                let tickHeight: CGFloat = isLarge ? 20 : 16
                
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.1))
                        .frame(height: barHeight)
                        .offset(y: (tickHeight - barHeight) / 2)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(habit.color.gradient)
                        .frame(width: geo.size.width * progress, height: barHeight)
                        .offset(y: (tickHeight - barHeight) / 2)
                    
                    // Tick marks
                    ForEach(0..<tickCount + 1, id: \.self) { index in
                        let xPosition = CGFloat(index) * tickSpacing
                        let isFilled = isTickFilled(index: index, total: tickCount)
                        
                        Rectangle()
                            .fill(isFilled ? habit.color.color : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.2)))
                            .frame(width: isLarge ? 2 : 1.5, height: tickHeight)
                            .position(x: xPosition, y: tickHeight / 2)
                    }
                }
                .frame(height: tickHeight)
            }
            .frame(height: isLarge ? 20 : 16)
            
            // Tick labels (not on small)
            if !isSmall {
                HStack {
                    Text(habit.startDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundColor(textColor.opacity(0.5))
                    Spacer()
                    if totalTicks > 2 {
                        Text("\(totalTicks / 2) \(habit.timelineTickUnit.displayName.lowercased())")
                            .font(.caption2)
                            .foregroundColor(textColor.opacity(0.5))
                        Spacer()
                    }
                    Text(calculatedTargetDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.caption2)
                        .foregroundColor(textColor.opacity(0.5))
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
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
        .description("Track your habit progress.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Widget Background
struct WidgetBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        colorScheme == .dark ? Color.black : Color.white
    }
}
