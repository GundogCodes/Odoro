// Uses the real widget model, timeline entry and rotation scheduler.
let rotationStart = Date(timeIntervalSince1970: 1_800_000_123)
var first = try makeHabit(days: 116)
first.id = UUID()
var second = try makeHabit(days: 7)
second.id = UUID()
second.visualStyle = .bar
var third = try makeHabit(days: 2)
third.id = UUID()
third.visualStyle = .text
var archived = try makeHabit(days: 10)
archived.id = UUID()
archived.isCompleted = true
let active = [first, second, third]
for interval: TimeInterval in [900, 1800, 3600] {
    let entries = HabitCycleSchedule.entries(habits: [first, archived, second, third], interval: interval, from: rotationStart)
    check(entries.count == Int(86400 / interval) + 1, "A full day of rotations")
    check(entries[0].date == rotationStart, "First entry is immediately available")
    check(Set(entries.compactMap { $0.habit?.id }) == Set(active.map(\.id)), "All active habits cycle, completed habits excluded")
    for (entry, next) in zip(entries, entries.dropFirst()) {
        check(next.date > entry.date, "Timeline dates strictly increase")
        let index = active.firstIndex { $0.id == entry.habit?.id }!
        check(next.habit?.id == active[(index + 1) % active.count].id, "Cycle follows habit list order and wraps")
    }
    let reload = HabitCycleSchedule.entries(habits: active, interval: interval, from: entries[2].date.addingTimeInterval(1))
    check(reload[0].habit?.id == entries[2].habit?.id, "Reloads do not restart the cycle")
    let single = HabitCycleSchedule.entries(habits: [first], interval: interval, from: rotationStart)
    check(single.allSatisfy { $0.habit?.id == first.id }, "One habit stays visible")
}
let empty = HabitCycleSchedule.entries(habits: [archived], interval: 900, from: rotationStart)
check(empty.count == 1 && empty[0].habit == nil, "Empty active list shows empty state")

var future = first
future.timelineDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
check(future.gridProgressCells == 117, "Future entries compute future progress")
let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(future)) as! [String: Any]
check(encoded["timelineDate"] == nil, "Rendering date never enters saved habit data")
print("Passed \(checks) total grid and cycling checks for widget")
