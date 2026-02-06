//
//  TaskAction.swift
//  MacScheduler
//
//  Defines the action types that can be performed by a scheduled task.
//

import Foundation

enum TaskActionType: String, Codable, CaseIterable {
    case executable = "Executable"
    case shellScript = "Shell Script"
    case appleScript = "AppleScript"

    var description: String {
        switch self {
        case .executable: return "Run an application or executable"
        case .shellScript: return "Run a shell script or command"
        case .appleScript: return "Run an AppleScript"
        }
    }

    var systemImage: String {
        switch self {
        case .executable: return "app.badge.checkmark"
        case .shellScript: return "terminal"
        case .appleScript: return "applescript"
        }
    }
}

struct TaskAction: Codable, Equatable, Identifiable {
    let id: UUID
    var type: TaskActionType
    var path: String
    var arguments: [String]
    var workingDirectory: String?
    var environmentVariables: [String: String]
    var scriptContent: String?

    init(id: UUID = UUID(),
         type: TaskActionType = .executable,
         path: String = "",
         arguments: [String] = [],
         workingDirectory: String? = nil,
         environmentVariables: [String: String] = [:],
         scriptContent: String? = nil) {
        self.id = id
        self.type = type
        self.path = path
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.environmentVariables = environmentVariables
        self.scriptContent = scriptContent
    }

    var displayName: String {
        if !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        return type.rawValue
    }

    var commandPreview: String {
        switch type {
        case .executable:
            if arguments.isEmpty {
                return path
            }
            return "\(path) \(arguments.joined(separator: " "))"
        case .shellScript:
            return scriptContent ?? path
        case .appleScript:
            if let script = scriptContent, !script.isEmpty {
                let preview = script.prefix(50)
                return script.count > 50 ? "\(preview)..." : String(preview)
            }
            return path
        }
    }

    func validate() -> [String] {
        var errors: [String] = []

        switch type {
        case .executable:
            if path.isEmpty {
                errors.append("Executable path is required")
            } else if !FileManager.default.fileExists(atPath: path) {
                errors.append("Executable not found at path: \(path)")
            }
        case .shellScript:
            if path.isEmpty && (scriptContent?.isEmpty ?? true) {
                errors.append("Script path or content is required")
            }
        case .appleScript:
            if path.isEmpty && (scriptContent?.isEmpty ?? true) {
                errors.append("AppleScript path or content is required")
            }
        }

        if let workDir = workingDirectory, !workDir.isEmpty {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(atPath: workDir, isDirectory: &isDir) || !isDir.boolValue {
                errors.append("Working directory does not exist: \(workDir)")
            }
        }

        return errors
    }
}
