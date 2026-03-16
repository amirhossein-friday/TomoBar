//
//  KeychainHelper.swift
//  TomoBar
//
//  Simple token storage using UserDefaults (personal use, sandboxed app).
//  Avoids macOS keychain password prompts in sandboxed context.
//

import Foundation

struct KeychainHelper {
    private static let key = "todoistApiToken"

    /// Save Todoist API token.
    static func save(token: String) -> Bool {
        UserDefaults.standard.set(token, forKey: key)
        return true
    }

    /// Load Todoist API token.
    static func load() -> String? {
        let token = UserDefaults.standard.string(forKey: key)
        return (token?.isEmpty == true) ? nil : token
    }

    /// Delete Todoist API token.
    static func delete() -> Bool {
        UserDefaults.standard.removeObject(forKey: key)
        return true
    }
}
