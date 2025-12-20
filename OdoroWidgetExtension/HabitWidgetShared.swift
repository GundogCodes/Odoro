//
//  HabitWidgetShared.swift
//  OdoroWidgetExtension
//
//  Widget extension types that EXACTLY mirror the main app's Habit model
//  Add this file to WIDGET EXTENSION target ONLY
//

import Foundation
import SwiftUI

// MARK: - App Group Configuration
struct AppGroupConfig {
    static let suiteName = "group.com.gunisharma.com"
    static let habitsKey = "sharedHabits"
}

// MARK: - Enums (MUST match main app exactly - same raw values)

enum HabitType: String, Codable, CaseIterable {
    case countdown = "Countdown"
    case countUp = "Count Up"
}

enum HabitUpdateMode: String, Codable, CaseIterable {
    case auto = "Auto Track"
    case manual = "Manual"
}

enum HabitVisualStyle: String, Codable, CaseIterable {
    case grid = "Progress Grid"
    case bar = "Timeline Bar"
    case text = "Text Counter"
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
    case half = "Small"
    case fullMedium = "Medium"
    case full = "Large"
    var displayName: String { rawValue }
}

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

enum GridDurationType: String, Codable, CaseIterable {
    case customRange = "Custom Range"
    case toTargetDate = "To Target Date"
    case indefinite = "Indefinite"
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

// MARK: - HabitNote (MUST match main app exactly)
struct HabitNote: Identifiable, Codable {
    var id: UUID
    var content: String
    var createdAt: Date
}

// MARK: - Habit (MUST match main app exactly - same property order)
struct Habit: Identifiable, Codable {
    var id: UUID
    var name: String
    var icon: String
    var type: HabitType
    var updateMode: HabitUpdateMode
    var visualStyle: HabitVisualStyle
    var widgetSize: HabitWidgetSize
    
    // Grid settings
    var cellUnit: CellUnit
    var durationType: GridDurationType
    var customDuration: Int
    var targetDate: Date?
    var textCounterDuration: Int
    var timelineTickUnit: TimelineTickUnit
    var timelineDuration: Int
    
    // Progress tracking
    var currentValue: Int
    var cycleCount: Int
    var manuallyFilledCells: Set<Int>
    
    // Notes & Completion
    var notes: [HabitNote]
    var isCompleted: Bool
    var completedAt: Date?
    
    // Display settings
    var timeUnit: HabitTimeUnit
    var color: HabitColor
    
    var createdAt: Date
    
    // Computed property (same as main app)
    var startDate: Date { createdAt }
    
    // MARK: - Computed Properties for Widget Display
    
    var maxCellCapacity: Int {
        switch widgetSize {
        case .half: return 49
        case .fullMedium: return 105
        case .full: return 210
        }
    }
    
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
    
    var gridPageInfo: (currentPage: Int, totalPages: Int, cellsInCurrentPage: Int, filledInCurrentPage: Int) {
        let totalDuration = totalDurationCells
        let capacity = maxCellCapacity
        let elapsed = elapsedCells
        
        if totalDuration <= capacity {
            return (0, 1, totalDuration, min(elapsed, totalDuration))
        }
        
        let totalPages = Int(ceil(Double(totalDuration) / Double(capacity)))
        let currentPage = min(elapsed / capacity, totalPages - 1)
        let cellsBeforeThisPage = currentPage * capacity
        let remainingCells = totalDuration - cellsBeforeThisPage
        let cellsInCurrentPage = min(remainingCells, capacity)
        let elapsedInCurrentPage = elapsed - cellsBeforeThisPage
        let filledInCurrentPage = max(0, min(elapsedInCurrentPage, cellsInCurrentPage))
        
        return (currentPage, totalPages, cellsInCurrentPage, filledInCurrentPage)
    }
    
    var totalCells: Int {
        return gridPageInfo.cellsInCurrentPage
    }
    
    var gridDimensions: (columns: Int, rows: Int) {
        let total = totalCells
        switch widgetSize {
        case .half:
            let maxCols = 7
            let maxRows = 7
            let side = Int(ceil(sqrt(Double(total))))
            let cols = min(side, maxCols)
            let rows = Int(ceil(Double(total) / Double(cols)))
            return (cols, min(rows, maxRows))
        case .fullMedium:
            let maxCols = 15
            let maxRows = 7
            let idealRows = max(1, Int(ceil(sqrt(Double(total) / 2.0))))
            let idealCols = Int(ceil(Double(total) / Double(idealRows)))
            let cols = min(idealCols, maxCols)
            let rows = min(Int(ceil(Double(total) / Double(cols))), maxRows)
            return (cols, rows)
        case .full:
            let maxCols = 15
            let maxRows = 14
            let idealRows = max(1, Int(ceil(sqrt(Double(total) / 1.5))))
            let idealCols = Int(ceil(Double(total) / Double(idealRows)))
            let cols = min(idealCols, maxCols)
            let rows = min(Int(ceil(Double(total) / Double(cols))), maxRows)
            return (cols, rows)
        }
    }
    
    func filledCells(at date: Date = Date()) -> Int {
        return gridPageInfo.filledInCurrentPage
    }
}

// MARK: - Data Store
class HabitDataStore {
    static let shared = HabitDataStore()
    
    private var userDefaults: UserDefaults? {
        UserDefaults(suiteName: AppGroupConfig.suiteName)
    }
    
    func loadHabits() -> [Habit] {
        guard let userDefaults = userDefaults else {
            print("❌ Widget: Cannot access App Group")
            return []
        }
        
        guard let data = userDefaults.data(forKey: AppGroupConfig.habitsKey) else {
            print("❌ Widget: No data found for key '\(AppGroupConfig.habitsKey)'")
            return []
        }
        
        print("📦 Widget: Found \(data.count) bytes of data")
        
        do {
            let habits = try JSONDecoder().decode([Habit].self, from: data)
            print("✅ Widget: Decoded \(habits.count) habits")
            return habits
        } catch let DecodingError.keyNotFound(key, context) {
            print("❌ Widget: Missing key '\(key.stringValue)' - \(context.debugDescription)")
        } catch let DecodingError.typeMismatch(type, context) {
            print("❌ Widget: Type mismatch for \(type) - \(context.debugDescription)")
            print("   Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        } catch let DecodingError.valueNotFound(type, context) {
            print("❌ Widget: Value not found for \(type) - \(context.debugDescription)")
        } catch {
            print("❌ Widget: Decoding error - \(error)")
        }
        
        return []
    }
    
    var activeHabits: [Habit] {
        loadHabits().filter { !$0.isCompleted }
    }
}
