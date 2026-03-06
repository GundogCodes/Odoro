# Odoro — Focus Timer & Habit Tracker

Odoro is a productivity app that combines a Pomodoro-style focus timer with a visual habit tracker. Built entirely in SwiftUI for iOS.

---

## Screenshots
<p align="center">
<img width="320" height="868" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-13 at 18 10 12" src="https://github.com/user-attachments/assets/e2c01057-21bc-4761-ad58-27dbc4fb70fc" />
<img width="320" height="868" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-13 at 18 09 37" src="https://github.com/user-attachments/assets/8c716c9b-8e17-4133-99f8-8aaf4d8f03bc" />
<img width="320" height="868" alt="Simulator Screenshot - iPhone 16 Pro Max - 2025-08-13 at 18 10 38" src="https://github.com/user-attachments/assets/fbc1b155-c780-4fb5-81c1-9bc42e0eb33c" />
</p>

---

## Features

### Focus Timer

- **Customizable study and rest durations** — Set your own session lengths in minutes using a smooth scroll picker.
- **Long break support** — Enable automatic long breaks after a configurable number of consecutive study sessions.
- **Fluid wave animation** — A 3-layer sine wave fills the screen as the timer progresses, with real-time tilt response using device motion.
- **Battery saver mode** — Switches to a minimal black background with a stroke-only wave outline, reducing power usage during long sessions.
- **Quick-adjust buttons** — Add or subtract 5 or 10 minutes on the fly while the timer is running. Circular buttons appear below the controls and auto-hide with the rest of the UI.
- **Background notifications** — Get notified when a session ends, even if the app is closed or in the background.
- **Live Activities** — See your timer countdown on the lock screen and Dynamic Island while the app is backgrounded.
- **Timer state restoration** — If the app is killed, Odoro restores the correct timer phase and remaining time on next launch, calculating how many study/rest cycles elapsed while it was closed.
- **Ambient sounds** — Play background sounds during study sessions. Sounds pause automatically during rest periods.
- **Auto-cycling** — Timer automatically transitions between study and rest phases without manual intervention.
- **Session tracking** — Tracks consecutive sessions, total study time, and daily streaks.
- **Customizable colors** — Choose separate colors for study and rest phases from 16 color options.
- **Mute mode** — Disable the completion ding sound while keeping notifications active.
- **Motivational quotes** — Random productivity quotes displayed on the timer screen.

### Habit Tracker

- **Three visual styles** — Track habits using a contribution grid (like GitHub), a timeline bar with tick marks, or a text counter with time breakdowns.
- **Countdown and count-up modes** — Track time remaining until a goal or time elapsed since starting a habit.
- **Auto and manual tracking** — Auto-tracked habits update based on elapsed time. Manual habits let you tap cells to mark progress yourself.
- **Grid pagination** — When a habit's duration exceeds the grid capacity, the grid automatically pages forward, keeping the display clean.
- **Full habit editing** — Edit every aspect of a habit after creation: name, icon, color, visual style, tracking mode, duration, target date, and start date.
- **Style conversion with confirmation** — Switch between grid, bar, and text counter styles with a confirmation prompt to prevent accidental changes.
- **40 icons across 7 categories** — Goals, health & fitness, mind & learning, nature, lifestyle, productivity, and misc. All displayed with clean names (no raw SF Symbol identifiers).
- **16 color options** — Blue, green, purple, orange, red, pink, teal, yellow, indigo, mint, cyan, brown, coral, lavender, lime, and gold. Each with a matching gradient.
- **Notes and journaling** — Add timestamped notes to any habit. View recent notes in the detail sheet or browse the full list. Delete individual notes.
- **Progress reset** — Reset a habit's progress without deleting it. Resets the reference date so elapsed calculations start fresh, while preserving notes and settings.
- **Goal tracking** — A gold-highlighted goal cell appears at the end of the grid. Notification when you reach your goal.
- **Hide/minimize habits** — Toggle an eye button to collapse all habit cards into compact minimal rows showing just icon, name, and a progress bar.
- **Reorderable habit list** — Drag to reorder your habits in the main view.
- **Completed habits section** — Mark habits as complete to move them to a separate section. View completion date and full history.
- **Context menu actions** — Long-press any habit card to quickly add a note, view notes, reset progress, or mark as complete.

### Home Screen Widgets

- **All three visual styles** — Grid, timeline bar, and text counter widgets, matching the in-app appearance.
- **Multiple sizes** — Small, medium, and large widget families supported.
- **Configurable** — Select which habit to display using App Intents.
- **Auto-refresh** — Widgets refresh every 5 minutes for auto-tracked habits, every 15 minutes for manual habits.
- **Resilient decoding** — Widget won't break if the main app adds new properties. Uses fallback defaults for any missing data.

### Settings & Customization

- **Study/rest/long break duration pickers** — Adjust session lengths from the settings panel.
- **Long break configuration** — Enable/disable long breaks and set how many sessions before one triggers.
- **Timer notifications toggle** — Control whether Odoro sends completion alerts.
- **Sound selection** — Choose from ambient background sounds for study sessions.
- **Study color and rest color pickers** — Separate color themes for each timer phase.
- **Daily study stats** — View total study time, current streak, and session counts.

---

## Tech Stack

- **SwiftUI** — Entire UI built natively in SwiftUI
- **WidgetKit** — Home screen widgets with App Intents configuration
- **ActivityKit** — Live Activities for lock screen and Dynamic Island
- **App Groups** — Shared data between the main app and widget extension
- **CoreMotion** — Device tilt affects the fluid wave animation
- **UserNotifications** — Background timer completion alerts
- **AVFoundation** — Ambient sound playback
- **UserDefaults** — Local data persistence (habits, settings, stats)

---

## Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/GundogCodes/odoro.git
   cd odoro
   ```
2. Open `Odoro.xcodeproj` in Xcode.
3. Select your target device or simulator and run.

---

## Privacy Policy
https://gundogcodes.github.io/odoro-privacy-policy/
