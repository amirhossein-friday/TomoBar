//
//  TasksView.swift
//  TomoBar
//
//  Tasks tab: browse and select Todoist tasks, filtered by project.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var timer: TBTimer
    @Binding var activeTab: ChildView
    @State private var selectedProjectId: String = "__all__"

    var body: some View {
        VStack {
            if !timer.todoist.hasToken {
                noTokenView
            } else {
                taskListView
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - No Token State

    private var noTokenView: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Connect Todoist to get started")
                .foregroundColor(.secondary)
            Button {
                activeTab = .settings
            } label: {
                Text("Go to Settings")
            }
            Spacer()
        }
    }

    // MARK: - Filtered tasks

    private var filteredGroups: [(project: TodoistProject, tasks: [TodoistTask])] {
        let all = timer.todoist.tasksByProject
        if selectedProjectId == "__all__" {
            return all
        }
        return all.filter { $0.project.id == selectedProjectId }
    }

    // MARK: - Task List View

    private var taskListView: some View {
        VStack(spacing: 6) {
            topBar

            if timer.todoist.isLoading {
                ProgressView()
                    .frame(height: 200)
            } else if let errorMessage = timer.todoist.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .frame(height: 200)
            } else {
                taskList
            }
        }
        .onAppear {
            timer.todoist.refreshIfStale()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 6) {
            // Project filter picker
            Picker("", selection: $selectedProjectId) {
                Text("All Projects").tag("__all__")
                ForEach(timer.todoist.projects, id: \.id) { project in
                    Text(project.name).tag(project.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)

            if timer.todoist.hasSelectedTask && timer.todoist.pomodoroCountForSelectedTask > 0 {
                Button {
                    timer.todoist.resetPomodoroCount()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .help("Reset pomodoro count")
            }

            Button {
                timer.todoist.refreshTasks()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh tasks")
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(filteredGroups, id: \.project.id) { group in
                    if selectedProjectId == "__all__" {
                        Text(group.project.name)
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }

                    ForEach(group.tasks, id: \.id) { task in
                        taskRow(for: task)
                    }
                }

                if filteredGroups.isEmpty {
                    Text("No tasks")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: 280)
    }

    // MARK: - Task Row

    private func taskRow(for task: TodoistTask) -> some View {
        Button {
            if timer.todoist.selectedTaskId == task.id {
                timer.todoist.deselectTask()
            } else {
                timer.todoist.selectTask(task)
            }
        } label: {
            HStack {
                Text(task.content)
                    .lineLimit(1)
                    .font(.system(size: 12))
                    .frameInfinityLeading()
                if timer.todoist.selectedTaskId == task.id {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 10))
                }
            }
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(
                timer.todoist.selectedTaskId == task.id
                    ? Color.accentColor.opacity(0.1)
                    : Color.clear
            )
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
