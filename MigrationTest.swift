#!/usr/bin/env swift
//
//  MigrationTest.swift
//
//  Run this standalone to prove that old Habit JSON (without resetHistory)
//  decodes correctly with the new custom init(from:).
//
//  Usage: In Terminal, cd to the Odoro folder and run:
//    swift MigrationTest.swift
//

import Foundation

// ──────────────────────────────────────────
// Minimal copies of the enums/types needed
// (just enough to test decoding)
// ──────────────────────────────────────────

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
    case seconds = "Seconds", minutes = "Minutes", hours = "Hours"
    case days = "Days", weeks = "Weeks", months = "Months", years = "Years"
}
enum TimelineTickUnit: String, Codable, CaseIterable {
    case minute = "Minutes", hour = "Hours", day = "Days"
    case week = "Weeks", month = "Months", year = "Years"
}
enum HabitWidgetSize: String, Codable, CaseIterable {
    case half = "Small", fullMedium = "Medium", full = "Large"
}
enum CellUnit: String, Codable, CaseIterable {
    case day = "Day", week = "Week", month = "Month", year = "Year"
}
enum GridDurationType: String, Codable, CaseIterable {
    case customRange = "Custom Range"
    case toTargetDate = "To Target Date"
    case indefinite = "Indefinite"
}
enum HabitColor: String, Codable, CaseIterable {
    case blue, green, purple, orange, red, pink, teal, yellow
    case indigo, mint, cyan, brown, coral, lavender, lime, gold
}

struct HabitNote: Identifiable, Codable {
    var id = UUID()
    var content: String
    var createdAt: Date
}

struct ResetEvent: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var progressAtReset: Int
    var durationAtReset: Int
}

// ──────────────────────────────────────────
// The NEW Habit struct with custom decoder
// (mirrors TrackerView.swift exactly)
// ──────────────────────────────────────────

struct Habit: Identifiable, Codable {
    var id = UUID()
    var name: String
    var icon: String
    var type: HabitType
    var updateMode: HabitUpdateMode
    var visualStyle: HabitVisualStyle
    var widgetSize: HabitWidgetSize
    var cellUnit: CellUnit
    var durationType: GridDurationType
    var customDuration: Int
    var targetDate: Date?
    var textCounterDuration: Int
    var timelineTickUnit: TimelineTickUnit
    var timelineDuration: Int
    var currentValue: Int
    var cycleCount: Int
    var manuallyFilledCells: Set<Int>
    var lastResetDate: Date?
    var resetHistory: [ResetEvent]      // <-- NEW FIELD
    var notes: [HabitNote]
    var isCompleted: Bool
    var completedAt: Date?
    var goalNotificationSent: Bool
    var timeUnit: HabitTimeUnit
    var color: HabitColor
    var createdAt: Date

    // Custom resilient decoder (same as in TrackerView.swift)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? "target"
        type = try container.decodeIfPresent(HabitType.self, forKey: .type) ?? .countUp
        updateMode = try container.decodeIfPresent(HabitUpdateMode.self, forKey: .updateMode) ?? .auto
        visualStyle = try container.decodeIfPresent(HabitVisualStyle.self, forKey: .visualStyle) ?? .grid
        widgetSize = try container.decodeIfPresent(HabitWidgetSize.self, forKey: .widgetSize) ?? .full
        cellUnit = try container.decodeIfPresent(CellUnit.self, forKey: .cellUnit) ?? .day
        durationType = try container.decodeIfPresent(GridDurationType.self, forKey: .durationType) ?? .customRange
        customDuration = try container.decodeIfPresent(Int.self, forKey: .customDuration) ?? 30
        targetDate = try container.decodeIfPresent(Date.self, forKey: .targetDate)
        textCounterDuration = try container.decodeIfPresent(Int.self, forKey: .textCounterDuration) ?? 30
        timelineTickUnit = try container.decodeIfPresent(TimelineTickUnit.self, forKey: .timelineTickUnit) ?? .day
        timelineDuration = try container.decodeIfPresent(Int.self, forKey: .timelineDuration) ?? 30
        currentValue = try container.decodeIfPresent(Int.self, forKey: .currentValue) ?? 0
        cycleCount = try container.decodeIfPresent(Int.self, forKey: .cycleCount) ?? 0
        manuallyFilledCells = try container.decodeIfPresent(Set<Int>.self, forKey: .manuallyFilledCells) ?? []
        lastResetDate = try container.decodeIfPresent(Date.self, forKey: .lastResetDate)
        resetHistory = try container.decodeIfPresent([ResetEvent].self, forKey: .resetHistory) ?? []
        notes = try container.decodeIfPresent([HabitNote].self, forKey: .notes) ?? []
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        goalNotificationSent = try container.decodeIfPresent(Bool.self, forKey: .goalNotificationSent) ?? false
        timeUnit = try container.decodeIfPresent(HabitTimeUnit.self, forKey: .timeUnit) ?? .days
        color = try container.decodeIfPresent(HabitColor.self, forKey: .color) ?? .blue
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

// ──────────────────────────────────────────
// TEST: Simulate OLD data (no resetHistory)
// ──────────────────────────────────────────

// This JSON represents what a habit saved BEFORE the update looks like.
// Notice: NO "resetHistory" key anywhere.
let oldFormatJSON = """
[
  {
    "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
    "name": "Semester 2",
    "icon": "book.fill",
    "type": "Count Up",
    "updateMode": "Auto Track",
    "visualStyle": "Timeline Bar",
    "widgetSize": "Medium",
    "cellUnit": "Day",
    "durationType": "To Target Date",
    "customDuration": 30,
    "targetDate": 796176000.0,
    "textCounterDuration": 30,
    "timelineTickUnit": "Days",
    "timelineDuration": 30,
    "currentValue": 0,
    "cycleCount": 0,
    "manuallyFilledCells": [],
    "notes": [
      {
        "id": "11111111-2222-3333-4444-555555555555",
        "content": "Started semester!",
        "createdAt": 789264000.0
      }
    ],
    "isCompleted": false,
    "goalNotificationSent": false,
    "timeUnit": "Days",
    "color": "blue",
    "createdAt": 789264000.0
  },
  {
    "id": "B2C3D4E5-F6A7-8901-BCDE-F12345678901",
    "name": "Workout Streak",
    "icon": "flame.fill",
    "type": "Count Up",
    "updateMode": "Manual",
    "visualStyle": "Progress Grid",
    "widgetSize": "Large",
    "cellUnit": "Day",
    "durationType": "Custom Range",
    "customDuration": 90,
    "textCounterDuration": 30,
    "timelineTickUnit": "Days",
    "timelineDuration": 30,
    "currentValue": 45,
    "cycleCount": 0,
    "manuallyFilledCells": [0,1,2,5,6,7,10,11,12,15,16,17,20,21,22],
    "notes": [],
    "isCompleted": false,
    "goalNotificationSent": false,
    "timeUnit": "Days",
    "color": "orange",
    "createdAt": 785894400.0
  }
]
""".data(using: .utf8)!

// ──────────────────────────────────────────
// RUN TESTS
// ──────────────────────────────────────────

var passed = 0
var failed = 0

func assert(_ condition: Bool, _ message: String) {
    if condition {
        passed += 1
        print("  ✅ \(message)")
    } else {
        failed += 1
        print("  ❌ FAIL: \(message)")
    }
}

print("═══════════════════════════════════════")
print("  MIGRATION SAFETY TEST")
print("═══════════════════════════════════════")
print()

// Test 1: Can we decode old data at all?
print("Test 1: Decoding old-format data (no resetHistory key)")
do {
    let habits = try JSONDecoder().decode([Habit].self, from: oldFormatJSON)

    assert(habits.count == 2, "Decoded 2 habits (got \(habits.count))")
    assert(habits[0].name == "Semester 2", "First habit name preserved: '\(habits[0].name)'")
    assert(habits[1].name == "Workout Streak", "Second habit name preserved: '\(habits[1].name)'")
    assert(habits[0].resetHistory.isEmpty, "resetHistory defaults to empty array")
    assert(habits[0].notes.count == 1, "Notes preserved: \(habits[0].notes.count) note(s)")
    assert(habits[0].notes[0].content == "Started semester!", "Note content preserved")
    assert(habits[1].manuallyFilledCells.count == 15, "Manual cells preserved: \(habits[1].manuallyFilledCells.count) cells")
    assert(habits[1].currentValue == 45, "currentValue preserved: \(habits[1].currentValue)")
    assert(habits[0].visualStyle == .bar, "Visual style preserved: \(habits[0].visualStyle)")
    assert(habits[0].durationType == .toTargetDate, "Duration type preserved: \(habits[0].durationType)")
    assert(habits[1].color == .orange, "Color preserved: \(habits[1].color)")
} catch {
    failed += 1
    print("  ❌ FATAL: Decoding threw an error: \(error)")
}

// Test 2: Re-encode and re-decode (round-trip)
print()
print("Test 2: Round-trip encode → decode (simulates save + load)")
do {
    let habits = try JSONDecoder().decode([Habit].self, from: oldFormatJSON)
    let reEncoded = try JSONEncoder().encode(habits)
    let reDecoded = try JSONDecoder().decode([Habit].self, from: reEncoded)

    assert(reDecoded.count == 2, "Round-trip preserved 2 habits")
    assert(reDecoded[0].name == "Semester 2", "Round-trip name intact")
    assert(reDecoded[0].resetHistory.isEmpty, "Round-trip resetHistory still empty")
    assert(reDecoded[1].manuallyFilledCells.count == 15, "Round-trip manual cells intact")
} catch {
    failed += 1
    print("  ❌ FATAL: Round-trip failed: \(error)")
}

// Test 3: New data WITH resetHistory also decodes fine
print()
print("Test 3: New-format data (with resetHistory) also works")
let newFormatJSON = """
[
  {
    "id": "C3D4E5F6-A7B8-9012-CDEF-123456789012",
    "name": "New Habit",
    "icon": "star.fill",
    "type": "Count Up",
    "updateMode": "Auto Track",
    "visualStyle": "Text Counter",
    "widgetSize": "Medium",
    "cellUnit": "Day",
    "durationType": "Custom Range",
    "customDuration": 60,
    "textCounterDuration": 60,
    "timelineTickUnit": "Days",
    "timelineDuration": 60,
    "currentValue": 0,
    "cycleCount": 0,
    "manuallyFilledCells": [],
    "resetHistory": [
      {
        "id": "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE",
        "date": 793900000.0,
        "progressAtReset": 25,
        "durationAtReset": 60
      }
    ],
    "notes": [],
    "isCompleted": false,
    "goalNotificationSent": false,
    "timeUnit": "Days",
    "color": "green",
    "createdAt": 789264000.0
  }
]
""".data(using: .utf8)!

do {
    let habits = try JSONDecoder().decode([Habit].self, from: newFormatJSON)

    assert(habits.count == 1, "Decoded 1 new-format habit")
    assert(habits[0].resetHistory.count == 1, "resetHistory has 1 event")
    assert(habits[0].resetHistory[0].progressAtReset == 25, "Reset event progress preserved: \(habits[0].resetHistory[0].progressAtReset)")
} catch {
    failed += 1
    print("  ❌ FATAL: New format decoding failed: \(error)")
}

// Test 4: Mixed array (old + new habits together)
print()
print("Test 4: Mixed array (old habits without resetHistory + new habits with it)")
do {
    let oldHabits = try JSONDecoder().decode([Habit].self, from: oldFormatJSON)
    let newHabits = try JSONDecoder().decode([Habit].self, from: newFormatJSON)
    let combined = oldHabits + newHabits
    let encoded = try JSONEncoder().encode(combined)
    let decoded = try JSONDecoder().decode([Habit].self, from: encoded)

    assert(decoded.count == 3, "All 3 habits survived round-trip")
    assert(decoded[0].resetHistory.isEmpty, "Old habit: resetHistory empty")
    assert(decoded[2].resetHistory.count == 1, "New habit: resetHistory preserved")
} catch {
    failed += 1
    print("  ❌ FATAL: Mixed array test failed: \(error)")
}

// ──────────────────────────────────────────
// RESULTS
// ──────────────────────────────────────────

print()
print("═══════════════════════════════════════")
if failed == 0 {
    print("  ALL \(passed) TESTS PASSED ✅")
    print("  Your existing habits will be safe.")
} else {
    print("  \(failed) TEST(S) FAILED ❌")
    print("  DO NOT deploy until these are fixed!")
}
print("═══════════════════════════════════════")
