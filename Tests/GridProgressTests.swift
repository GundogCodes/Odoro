import Foundation

func makeHabit(days: Int, duration: GridDurationType = .indefinite,
               total: Int = 300, size: HabitWidgetSize = .fullMedium,
               type: HabitType = .countUp) throws -> Habit {
    // Decode the real model using the old saved-habit format (no new keys).
    let data = Data("{\"id\":\"A1B2C3D4-E5F6-7890-ABCD-EF1234567890\",\"name\":\"noPop\"}".utf8)
    var habit = try JSONDecoder().decode(Habit.self, from: data)
    habit.createdAt = Calendar.current.date(byAdding: .day, value: -days, to: Date())!.addingTimeInterval(-60)
    habit.durationType = duration
    habit.customDuration = total
    habit.widgetSize = size
    habit.type = type
    return habit
}

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    precondition(condition(), message)
}

for size in HabitWidgetSize.allCases {
    let sample = try makeHabit(days: 0, size: size)
    let capacity = sample.maxCellCapacity
    for days in [0, capacity - 1, capacity, capacity + 1, capacity * 3 + 11] {
        for type in HabitType.allCases {
            let habit = try makeHabit(days: days, size: size, type: type)
            check(habit.gridPageInfo.currentPage == days / capacity, "Indefinite page boundary")
            check(habit.gridPageInfo.filledInCurrentPage == days % capacity, "Indefinite page progress")
            check(habit.filledCellsForDisplay() == (type == .countUp ? days % capacity : capacity - days % capacity), "Count-up/countdown page fill")
            check(habit.fullGridCellCount >= days + 30, "Indefinite full history and padding")
            check(!habit.isGoalReached, "Indefinite has no goal")
            let offset = habit.gridPageInfo.currentPage * capacity
            let filled = (0..<habit.totalCells).filter { habit.gridCellIsFilled(at: offset + $0) }.count
            check(filled == habit.filledCellsForDisplay(), "Cell rendering agrees with page counts")
        }
    }
    // Test every finite size, including awkward near-capacity dimensions.
    for total in 4...(capacity * 2 + 1) {
        let habit = try makeHabit(days: 0, duration: .customRange, total: total, size: size)
        check(habit.gridDimensions.columns * habit.gridDimensions.rows >= habit.totalCells, "No cells clipped by dimensions")
    }
}

var noPop = try makeHabit(days: 116)
check(noPop.gridPageInfo.currentPage == 1, "noPop is on page two")
check(noPop.filledCellsForDisplay() == 11, "noPop medium shows 11 cells")
check(noPop.gridProgressLabel == "116d completed", "noPop retains total count")
check((0..<noPop.fullGridCellCount).filter { noPop.gridCellIsFilled(at: $0) }.count == 116, "Full history contains all 116 completed days")
noPop.widgetSize = .full
check(noPop.filledCellsForDisplay() == 116, "Resizing does not change total progress")

for total in [105, 106, 210, 211, 300] {
    for days in [0, 104, 105, 106, 209, 210, total, total + 116] {
        for type in HabitType.allCases {
            let habit = try makeHabit(days: days, duration: .customRange, total: total, type: type)
            check(habit.gridProgressCells == min(days, total), "Finite progress stops at target")
            check(habit.fullGridCellCount == total, "Finite detail includes whole duration")
            let filled = (0..<total).filter { habit.gridCellIsFilled(at: $0) }.count
            check(filled == (type == .countUp ? min(days, total) : max(0, total - days)), "Full count-up/countdown progression")
            if days >= total {
                check(habit.gridPageInfo.currentPage == (total - 1) / 105, "Final page never cycles")
                check(habit.filledCellsForDisplay() == (type == .countUp ? habit.totalCells : 0), "Final page stays full/empty")
                check(habit.isGoalReached, "Goal reached")
            }
        }
    }
}

var targeted = try makeHabit(days: 116, duration: .toTargetDate)
targeted.targetDate = Calendar.current.date(byAdding: .day, value: 300, to: targeted.createdAt)
check(targeted.totalDurationCells == 300, "Target date duration")
check(targeted.gridPageInfo.currentPage == 1 && targeted.filledCellsForDisplay() == 11, "Target date pagination")

var manual = try makeHabit(days: 116)
manual.updateMode = .manual
manual.manuallyFilledCells = [0, 5, 104, 105, 115, 116]
manual.currentValue = manual.manuallyFilledCells.count
check(manual.gridPageInfo.currentPage == 1, "Manual page shows today despite missed days")
check(manual.filledCellsForDisplay() == 3, "Manual page uses absolute positions")
check(manual.gridProgressLabel == "6d completed", "Manual label counts all pages")
check(manual.gridCellIsFilled(at: 104) && manual.gridCellIsFilled(at: 116), "Manual detail preserves earlier pages")
manual.type = .countdown
check(manual.filledCellsForDisplay() == 102, "Manual countdown empties checked cells")
check(!manual.gridCellIsFilled(at: 198) && manual.gridCellIsFilled(at: 197), "Manual countdown rendering")
let roundTrip = try JSONDecoder().decode(Habit.self, from: JSONEncoder().encode(manual))
check(roundTrip.manuallyFilledCells == manual.manuallyFilledCells, "Saved history round-trips")

var reset = try makeHabit(days: 116)
reset.lastResetDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!.addingTimeInterval(-60)
check(reset.elapsedCells == 2 && reset.currentCellIndex == 2, "Reset starts auto and manual cell positions together")
var completed = try makeHabit(days: 116)
completed.isCompleted = true
completed.completedAt = Calendar.current.date(byAdding: .day, value: 105, to: completed.createdAt)!.addingTimeInterval(60)
check(completed.gridProgressCells == 105, "Archived history freezes at completion")
// Indefinite countdowns empty right-to-left, bottom-to-top, on every page.
for size in HabitWidgetSize.allCases {
    let capacity = try makeHabit(days: 0, size: size).maxCellCapacity
    for elapsed in [0, 1, capacity - 1, capacity, capacity + 1, capacity * 2 + 11] {
        let habit = try makeHabit(days: elapsed, size: size, type: .countdown)
        let offset = habit.gridPageInfo.currentPage * capacity
        let remaining = capacity - elapsed % capacity
        for index in 0..<capacity {
            check(habit.gridCellIsFilled(at: offset + index) == (index < remaining), "Countdown empties from bottom-right and restarts full")
        }
        let fullCount = habit.fullGridCellCount
        for index in 0..<fullCount {
            check(habit.gridCellIsFilled(at: index, fullGrid: true) == (index < fullCount - elapsed), "Full indefinite countdown reverses entire history")
        }
    }
}
// Finite countdowns reverse each page, including a short final page, and stop empty.
for duration in [GridDurationType.customRange, .toTargetDate] {
    for total in [4, 105, 106, 211, 300] {
        for elapsed in [0, 1, 104, 105, 106, 210, total, total + 1] {
            var habit = try makeHabit(days: elapsed, duration: duration, total: total, type: .countdown)
            if duration == .toTargetDate {
                habit.targetDate = Calendar.current.date(byAdding: .day, value: total, to: habit.createdAt)
            }
            let page = habit.gridPageInfo
            let offset = page.currentPage * habit.maxCellCapacity
            let remaining = page.cellsInCurrentPage - page.filledInCurrentPage
            for index in 0..<page.cellsInCurrentPage {
                check(habit.gridCellIsFilled(at: offset + index) == (index < remaining), "Finite countdown reverses current page")
            }
            for index in 0..<total {
                check(habit.gridCellIsFilled(at: index, fullGrid: true) == (index < max(0, total - elapsed)), "Finite countdown detail empties from bottom-right")
            }
        }
    }
}
var manualStart = try makeHabit(days: 0, type: .countdown)
manualStart.updateMode = .manual
manualStart.manuallyFilledCells = [0]
manualStart.currentValue = 1
check(!manualStart.gridCellIsFilled(at: 104), "First manual check empties bottom-right")
check(manualStart.gridCellIsFilled(at: 0), "First manual check leaves top-left filled")
check(!manualStart.gridCellIsFilled(at: manualStart.fullGridCellCount - 1, fullGrid: true), "Manual detail also empties bottom-right")

print("Passed \(checks) grid regression checks")
