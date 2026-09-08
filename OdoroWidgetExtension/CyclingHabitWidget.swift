import AppIntents
import SwiftUI
import WidgetKit

// Prepare a full day of rotations so cycling doesn't require a reload each time.
enum HabitCycleSchedule {
    static func entries(habits: [Habit], interval: TimeInterval, from now: Date) -> [HabitWidgetEntry] {
        let active = habits.filter { !$0.isCompleted }
        guard !active.isEmpty else { return [HabitWidgetEntry(date: now, habit: nil)] }
        let step = max(15 * 60, interval)
        let currentSlot = Int(floor(now.timeIntervalSince1970 / step))
        // A stable clock anchor prevents app-triggered reloads from restarting the cycle.
        func entry(slot: Int, date: Date) -> HabitWidgetEntry {
            let index = ((slot % active.count) + active.count) % active.count
            return HabitWidgetEntry(date: date, habit: active[index])
        }
        var entries = [entry(slot: currentSlot, date: now)]
        let end = now.addingTimeInterval(24 * 60 * 60)
        var slot = currentSlot + 1
        while Date(timeIntervalSince1970: Double(slot) * step) <= end {
            entries.append(entry(slot: slot, date: Date(timeIntervalSince1970: Double(slot) * step)))
            slot += 1
        }
        return entries
    }
}

struct CyclingHabitWidgetProvider: AppIntentTimelineProvider {
    typealias Entry = HabitWidgetEntry
    typealias Intent = CycleHabitsIntent

    func placeholder(in context: Context) -> HabitWidgetEntry {
        HabitWidgetEntry(date: Date(), habit: nil)
    }

    func snapshot(for configuration: CycleHabitsIntent, in context: Context) async -> HabitWidgetEntry {
        HabitCycleSchedule.entries(
            habits: HabitDataStore.shared.activeHabits,
            interval: configuration.interval.seconds,
            from: Date()
        )[0]
    }

    func timeline(for configuration: CycleHabitsIntent, in context: Context) async -> Timeline<HabitWidgetEntry> {
        let now = Date()
        let entries = HabitCycleSchedule.entries(
            habits: HabitDataStore.shared.activeHabits,
            interval: configuration.interval.seconds,
            from: now
        )
        if entries[0].habit == nil {
            return Timeline(entries: entries, policy: .after(now.addingTimeInterval(60 * 60)))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct CyclingHabitWidget: Widget {
    let kind = "CyclingHabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CycleHabitsIntent.self,
            provider: CyclingHabitWidgetProvider()
        ) { entry in
            HabitWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackground(tint: entry.habit?.color.color ?? .purple)
                }
        }
        .configurationDisplayName("Cycling Habit Tracker")
        .description("Rotate through all your active habits at your chosen interval.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .containerBackgroundRemovable(true)
    }
}
