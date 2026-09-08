import Foundation
import WidgetKit

// Put constants somewhere global (top-level) or in a type.
enum WidgetConfig {
    static let suiteName = "group.com.gunisharma.odoro"
    static let habitsKey = "sharedHabits"
    static let habitsFileName = "sharedHabits.json"
}

extension HabitManager {

    /// Call this after any habit data changes to sync to the widget
    func syncToWidget() {
        guard let encoded = try? JSONEncoder().encode(habits) else {
            print("❌ syncToWidget: Failed to encode habits")
            return
        }

        // An atomic file is immediately visible to the widget process before
        // WidgetKit handles the reload request. Keep UserDefaults as a fallback
        // for existing installs and for compatibility with older widgets.
        if let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetConfig.suiteName
        ) {
            let fileURL = containerURL.appendingPathComponent(WidgetConfig.habitsFileName)
            do {
                try encoded.write(to: fileURL, options: .atomic)
            } catch {
                print("❌ syncToWidget: Failed to save shared file: \(error)")
            }
        } else {
            print("❌ syncToWidget: Failed to access App Group container")
        }

        if let userDefaults = UserDefaults(suiteName: WidgetConfig.suiteName) {
            userDefaults.set(encoded, forKey: WidgetConfig.habitsKey)
            print("✅ syncToWidget: Saved \(habits.count) habits to App Group")
        } else {
            print("❌ syncToWidget: Failed to access App Group preferences")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "CyclingHabitWidget")
    }
}
