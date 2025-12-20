import Foundation
import WidgetKit

// Put constants somewhere global (top-level) or in a type.
enum WidgetConfig {
    static let suiteName = "group.com.gunisharma.com"
    static let habitsKey = "sharedHabits"
}

extension HabitManager {

    /// Call this after any habit data changes to sync to the widget
    func syncToWidget() {
        guard let defaults = UserDefaults(suiteName: WidgetConfig.suiteName) else {
            print("❌ App cannot access App Group (check entitlement on MAIN APP target)")
            return
        }

        do {
            let data = try JSONEncoder().encode(habits)
            defaults.set(data, forKey: WidgetConfig.habitsKey)
            print("✅ App wrote \(habits.count) habits to App Group")
        } catch {
            print("❌ App failed to encode habits: \(error)")
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
    }
}
