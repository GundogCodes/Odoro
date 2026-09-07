//
//  HabitWidgetIntent.swift
//  OdoroWidgetExtension
//
//  AppIntent for selecting which habit to display in widget
//  Add this file to WIDGET EXTENSION target ONLY
//

import AppIntents
import WidgetKit

// MARK: - Habit Entity for Widget Selection
struct HabitEntity: AppEntity {
    var id: String
    var name: String
    var icon: String
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Habit"
    static var defaultQuery = HabitEntityQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            image: .init(systemName: icon)
        )
    }
}

// MARK: - Query for Available Habits
struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HabitEntity] {
        let habits = HabitDataStore.shared.activeHabits
        return identifiers.compactMap { id in
            guard let habit = habits.first(where: { $0.id.uuidString == id }) else { return nil }
            return HabitEntity(id: habit.id.uuidString, name: habit.name, icon: habit.icon)
        }
    }
    
    func suggestedEntities() async throws -> [HabitEntity] {
        let habits = HabitDataStore.shared.activeHabits
        return habits.map { HabitEntity(id: $0.id.uuidString, name: $0.name, icon: $0.icon) }
    }
    
    func defaultResult() async -> HabitEntity? {
        guard let habit = HabitDataStore.shared.activeHabits.first else { return nil }
        return HabitEntity(id: habit.id.uuidString, name: habit.name, icon: habit.icon)
    }
}

// MARK: - Widget Configuration Intent
struct SelectHabitIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Habit"
    static var description: IntentDescription = "Choose which habit to display"
    
    @Parameter(title: "Habit")
    var habit: HabitEntity?
}

// MARK: - Cycling Widget Configuration

enum HabitCycleInterval: String, AppEnum {
    case fifteenMinutes, thirtyMinutes, oneHour

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Cycle Interval"
    static var caseDisplayRepresentations: [HabitCycleInterval: DisplayRepresentation] = [
        .fifteenMinutes: "15 minutes",
        .thirtyMinutes: "30 minutes",
        .oneHour: "1 hour"
    ]

    var seconds: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        }
    }
}

struct CycleHabitsIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Cycle Habits"
    static var description: IntentDescription = "Rotate through all active habits in list order."

    @Parameter(title: "Change Habit Every", default: .fifteenMinutes)
    var interval: HabitCycleInterval
}
