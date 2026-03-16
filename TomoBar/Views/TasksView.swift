//
//  TasksView.swift
//  TomoBar
//
//  Tasks tab: browse and select Todoist tasks grouped by project.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject var timer: TBTimer
    @Binding var activeTab: ChildView

    var body: some View {
        VStack {
            if !timer.todoist.hasToken {
                noTokenView
            } else {
                taskListView
            }
        }
        .padding(4)
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

    // MARK: - Task List View

    private var taskListView: some View {
        VStack(spacing: 8) {
            topBar

            if timer.todoist.isLoading {
                ProgressView()
                    .frame(maxHeight: .infinity)
            } else if let errorMessage = timer.todoist.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.secondary)
                    .frame(maxHeight: .infinity)
            } else {
                taskList
            }

            Spacer().frame(minHeight: 0)
        }
        .onAppear {
            timer.todoist.refreshIfStale()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            if timer.todoist.hasSelectedTask && timer.todoist.pomodoroCountForSelectedTask > 0 {
                Button {
                    timer.todoist.resetPomodoroCount()
                } label: {
                    Text("Reset count")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                timer.todoist.refreshTasks()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(timer.todoist.tasksByProject, id: \.project.id) { group in
                    Text(group.project.name)
                        .font(.headline)
                        .bold()
                        .frameInfinityLeading()

                    ForEach(group.tasks, id: \.id) { task in
                        taskRow(for: task)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
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
                    .frameInfinityLeading()
                if timer.todoist.selectedTaskId == task.id {
                    Image(systemName: "checkmark")
                }
            }
        }
        .buttonStyle(.plain)
    }
}
