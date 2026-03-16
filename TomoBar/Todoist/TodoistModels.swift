//
//  TodoistModels.swift
//  TomoBar
//
//  Created by Todoist Integration on 2026-03-16.
//

import Foundation

/// Todoist project data transfer object
struct TodoistProject: Codable, Identifiable {
    let id: String
    let name: String
}

/// Todoist task data transfer object
struct TodoistTask: Codable, Identifiable {
    let id: String
    let content: String
    let projectId: String

    enum CodingKeys: String, CodingKey {
        case id
        case content
        case projectId = "project_id"
    }
}

/// Wrapper for Todoist API v1 paginated responses
struct TodoistPagedResponse<T: Decodable>: Decodable {
    let results: [T]
}
