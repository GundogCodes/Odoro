import Foundation
import WidgetKit

// Put constants somewhere global (top-level) or in a type.
enum WidgetConfig {
    static let suiteName = "group.com.gunisharma.odoro"
    static let habitsKey = "sharedHabits"
}

extension HabitManager {

    /// Call this after any habit data changes to sync to the widget
    func syncToWidget() {
        guard let userDefaults = UserDefaults(suiteName: WidgetConfig.suiteName) else {
            print("❌ syncToWidget: Failed to access App Group")
            return
        }
        
        if let encoded = try? JSONEncoder().encode(habits) {
            userDefaults.set(encoded, forKey: WidgetConfig.habitsKey)
            print("✅ syncToWidget: Saved \(habits.count) habits to App Group")
        }
        
        WidgetCenter.shared.reloadTimelines(ofKind: "HabitWidget")
    }
}
