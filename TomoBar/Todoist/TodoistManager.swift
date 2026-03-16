//
//  TodoistManager.swift
//  TomoBar
//
//  Orchestrator for Todoist integration: token management, task selection,
//  pomodoro counting, and auto-logging.
//

import Foundation
import SwiftUI

class TodoistManager: ObservableObject {

    // MARK: - TokenStatus

    enum TokenStatus {
        case none
        case verifying
        case connected
        case invalid
    }

    // MARK: - Published properties

    @Published var projects: [TodoistProject] = []
    @Published var tasks: [TodoistTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var tokenStatus: TokenStatus = .none

    // MARK: - AppStorage properties

    @AppStorage("selectedTodoistTaskId") var selectedTaskId: String = ""
    @AppStorage("selectedTodoistTaskName") var selectedTaskName: String = ""
    @AppStorage("showTaskInMenuBar") var showTaskInMenuBar: Bool = true
    @AppStorage("todoistPomodoroCountsV1") private var countsData: Data = Data()

    // MARK: - Private state

    private var lastFetchTime: Date?

    // MARK: - Computed properties

    var hasToken: Bool {
        KeychainHelper.load() != nil
    }

    var hasSelectedTask: Bool {
        !selectedTaskId.isEmpty
    }

    var pomodoroCountForSelectedTask: Int {
        let counts = decodeCounts()
        return counts[selectedTaskId] ?? 0
    }

    /// Groups tasks by projectId, matches to projects, sorted by project name.
    /// Tasks without a matching project go under "No Project".
    var tasksByProject: [(project: TodoistProject, tasks: [TodoistTask])] {
        let projectMap = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
        let grouped = Dictionary(grouping: tasks) { $0.projectId }

        var result: [(project: TodoistProject, tasks: [TodoistTask])] = []
        var unmatchedTasks: [TodoistTask] = []

        for (projectId, projectTasks) in grouped {
            if let project = projectMap[projectId] {
                result.append((project: project, tasks: projectTasks))
            } else {
                unmatchedTasks.append(contentsOf: projectTasks)
            }
        }

        result.sort { $0.project.name.localizedCaseInsensitiveCompare($1.project.name) == .orderedAscending }

        if !unmatchedTasks.isEmpty {
            let noProject = TodoistProject(id: "", name: "No Project")
            result.append((project: noProject, tasks: unmatchedTasks))
        }

        return result
    }

    // MARK: - Init

    init() {
        if KeychainHelper.load() != nil {
            tokenStatus = .connected
        }
    }

    // MARK: - Token management

    /// Verify token by saving to Keychain and fetching projects.
    /// On success: connected + refresh tasks. On failure: delete token, mark invalid.
    func verifyToken(_ token: String) {
        tokenStatus = .verifying
        errorMessage = nil

        Task {
            do {
                _ = KeychainHelper.save(token: token)
                let service = TodoistService(token: token)
                let fetchedProjects = try await service.fetchProjects()
                self.projects = fetchedProjects
                self.tokenStatus = .connected
                self.refreshTasks()
            } catch {
                _ = KeychainHelper.delete()
                self.tokenStatus = .invalid
                self.errorMessage = "Token verification failed: \(error.localizedDescription)"
            }
        }
    }

    /// Disconnect: delete token, clear state.
    func disconnect() {
        _ = KeychainHelper.delete()
        selectedTaskId = ""
        selectedTaskName = ""
        projects = []
        tasks = []
        tokenStatus = .none
        errorMessage = nil
        lastFetchTime = nil
    }

    // MARK: - Task fetching

    /// Refresh projects and tasks concurrently. Guards on token presence.
    func refreshTasks() {
        guard hasToken else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                guard let token = KeychainHelper.load() else {
                    self.isLoading = false
                    return
                }
                let service = TodoistService(token: token)

                async let fetchedProjects = service.fetchProjects()
                async let fetchedTasks = service.fetchTasks()

                self.projects = try await fetchedProjects
                self.tasks = try await fetchedTasks
                self.lastFetchTime = Date()
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to fetch tasks: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }

    /// Refresh only if last fetch was > 5 minutes ago or never.
    func refreshIfStale() {
        guard hasToken else { return }
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < 300 {
            return
        }
        refreshTasks()
    }

    // MARK: - Task selection

    func selectTask(_ task: TodoistTask) {
        selectedTaskId = task.id
        selectedTaskName = task.content
    }

    func deselectTask() {
        selectedTaskId = ""
        selectedTaskName = ""
    }

    // MARK: - Pomodoro counting

    /// Increment count for selected task. Returns new count.
    @discardableResult
    func incrementPomodoroCount() -> Int {
        var counts = decodeCounts()
        let current = counts[selectedTaskId] ?? 0
        let newCount = current + 1
        counts[selectedTaskId] = newCount
        encodeCounts(counts)
        return newCount
    }

    /// Remove count entry for selected task.
    func resetPomodoroCount() {
        var counts = decodeCounts()
        counts.removeValue(forKey: selectedTaskId)
        encodeCounts(counts)
    }

    // MARK: - Pomodoro logging

    /// Log a completed pomodoro as a comment on the selected Todoist task.
    /// Non-blocking: fires a detached Task for the API call with one retry.
    func logPomodoro(workMinutes: Int) {
        guard workMinutes > 0, hasSelectedTask, hasToken else { return }

        let count = incrementPomodoroCount()
        let comment = "\u{1F345} Pomodoro #\(count) completed (\(workMinutes) min)"
        let taskId = selectedTaskId

        Task.detached {
            guard let token = KeychainHelper.load() else { return }
            let service = TodoistService(token: token)

            do {
                try await service.postComment(taskId: taskId, content: comment)
            } catch {
                // Retry once after 2 seconds
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                do {
                    try await service.postComment(taskId: taskId, content: comment)
                } catch {
                    print("Todoist: comment posting failed: \(error)")
                }
            }
        }
    }

    // MARK: - Private helpers

    private func decodeCounts() -> [String: Int] {
        guard !countsData.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: Int].self, from: countsData)) ?? [:]
    }

    private func encodeCounts(_ counts: [String: Int]) {
        countsData = (try? JSONEncoder().encode(counts)) ?? Data()
    }
}
