import WidgetKit
import SwiftUI

// MARK: - Shared App Group Identifier
private let appGroupId = "group.com.focus.personalOs"

// MARK: - Overview Widget Entry
struct FocusOverviewEntry: TimelineEntry {
    let date: Date
    let scorePct: String
    let scoreTitle: String
    let tasksSummary: String
    let habitsSummary: String
    let timeText: String
}

struct FocusOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusOverviewEntry {
        FocusOverviewEntry(
            date: Date(),
            scorePct: "85%",
            scoreTitle: "OPTIMAL",
            tasksSummary: "2 of 3 tasks done",
            habitsSummary: "1 of 2 habits completed",
            timeText: "Offline"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusOverviewEntry) -> ()) {
        let prefs = UserDefaults(suiteName: appGroupId)
        let entry = FocusOverviewEntry(
            date: Date(),
            scorePct: prefs?.string(forKey: "score_pct") ?? "85%",
            scoreTitle: prefs?.string(forKey: "score_title") ?? "OPTIMAL",
            tasksSummary: prefs?.string(forKey: "tasks_summary") ?? "2 of 3 tasks done",
            habitsSummary: prefs?.string(forKey: "habits_summary") ?? "1 of 2 habits completed",
            timeText: prefs?.string(forKey: "time_text") ?? "Offline"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusOverviewEntry>) -> ()) {
        getSnapshot(in: context) { entry in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct FocusOverviewWidgetView: View {
    var entry: FocusOverviewEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .frame(width: 8, height: 8)
                Text("FOCUS OS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.scoreTitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)
            }
            Spacer()
            HStack(spacing: 12) {
                Text(entry.scorePct)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.tasksSummary)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.9))
                    Text(entry.habitsSummary)
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.6))
                }
            }
            Spacer()
            Text(entry.timeText)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Color(white: 0.4))
        }
        .padding(14)
        .background(Color.black)
        .widgetURL(URL(string: "focus://dashboard"))
    }
}

// MARK: - Tasks Widget Entry
struct FocusTasksEntry: TimelineEntry {
    let date: Date
    let taskCount: String
    let task1Title: String
    let task1Priority: String
    let task2Title: String
    let task2Priority: String
    let timeText: String
}

struct FocusTasksProvider: TimelineProvider {
    func placeholder(in context: Context) -> FocusTasksEntry {
        FocusTasksEntry(
            date: Date(),
            taskCount: "3 PENDING",
            task1Title: "Complete system audit",
            task1Priority: "CRIT",
            task2Title: "Sync local calendar events",
            task2Priority: "HIGH",
            timeText: "Offline"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusTasksEntry) -> ()) {
        let prefs = UserDefaults(suiteName: appGroupId)
        let entry = FocusTasksEntry(
            date: Date(),
            taskCount: prefs?.string(forKey: "tasks_count_badge") ?? "3 PENDING",
            task1Title: prefs?.string(forKey: "task_1_title") ?? "Complete system audit",
            task1Priority: prefs?.string(forKey: "task_1_priority") ?? "CRIT",
            task2Title: prefs?.string(forKey: "task_2_title") ?? "Sync local calendar events",
            task2Priority: prefs?.string(forKey: "task_2_priority") ?? "HIGH",
            timeText: prefs?.string(forKey: "time_text") ?? "Offline"
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusTasksEntry>) -> ()) {
        getSnapshot(in: context) { entry in
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
}

struct FocusTasksWidgetView: View {
    var entry: FocusTasksEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Rectangle()
                    .fill(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .frame(width: 8, height: 8)
                Text("TASKS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(entry.taskCount)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle().fill(Color(white: 0.3)).frame(width: 5, height: 5)
                    Text(entry.task1Title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                    Text(entry.task1Priority)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 1.0, green: 0.23, blue: 0.19))
                }
                HStack {
                    Circle().fill(Color(white: 0.3)).frame(width: 5, height: 5)
                    Text(entry.task2Title)
                        .font(.system(size: 11))
                        .foregroundColor(Color(white: 0.8))
                        .lineLimit(1)
                    Spacer()
                    Text(entry.task2Priority)
                        .font(.system(size: 8))
                        .foregroundColor(Color(red: 1.0, green: 0.58, blue: 0.0))
                }
            }
            Spacer()
            HStack {
                Text("+ ADD TASK")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)
                Spacer()
                Text(entry.timeText)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
            }
        }
        .padding(14)
        .background(Color.black)
        .widgetURL(URL(string: "focus://tasks"))
    }
}
