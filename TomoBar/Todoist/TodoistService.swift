//
//  TodoistService.swift
//  TomoBar
//
//  Created by Todoist Integration on 2026-03-16.
//

import Foundation

/// URLSession-based API client for Todoist REST API v2
class TodoistService {
    private let token: String
    private let baseURL = "https://api.todoist.com/rest/v2"

    init(token: String) {
        self.token = token
    }

    /// Fetch all projects from Todoist
    func fetchProjects() async throws -> [TodoistProject] {
        let url = URL(string: "\(baseURL)/projects")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistServiceError.invalidResponse
        }

        return try JSONDecoder().decode([TodoistProject].self, from: data)
    }

    /// Fetch all tasks from Todoist
    func fetchTasks() async throws -> [TodoistTask] {
        let url = URL(string: "\(baseURL)/tasks")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistServiceError.invalidResponse
        }

        return try JSONDecoder().decode([TodoistTask].self, from: data)
    }

    /// Post a comment to a task
    func postComment(taskId: String, content: String) async throws {
        let url = URL(string: "\(baseURL)/comments")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "task_id": taskId,
            "content": content
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TodoistServiceError.invalidResponse
        }
    }
}

/// Errors thrown by TodoistService
enum TodoistServiceError: Error {
    case invalidResponse
}
