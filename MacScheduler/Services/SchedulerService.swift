//
//  SchedulerService.swift
//  MacScheduler
//
//  Protocol defining the interface for scheduler backends.
//

import Foundation

enum SchedulerError: LocalizedError {
    case taskNotFound(UUID)
    case plistCreationFailed(String)
    case plistLoadFailed(String)
    case plistUnloadFailed(String)
    case commandExecutionFailed(String)
    case invalidTask(String)
    case cronUpdateFailed(String)
    case permissionDenied(String)
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .taskNotFound(let id):
            return "Task not found: \(id)"
        case .plistCreationFailed(let reason):
            return "Failed to create plist: \(reason)"
        case .plistLoadFailed(let reason):
            return "Failed to load task: \(reason)"
        case .plistUnloadFailed(let reason):
            return "Failed to unload task: \(reason)"
        case .commandExecutionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .invalidTask(let reason):
            return "Invalid task: \(reason)"
        case .cronUpdateFailed(let reason):
            return "Failed to update crontab: \(reason)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .fileSystemError(let reason):
            return "File system error: \(reason)"
        }
    }
}

protocol SchedulerService {
    var backend: SchedulerBackend { get }

    func install(task: ScheduledTask) async throws
    func uninstall(task: ScheduledTask) async throws
    func enable(task: ScheduledTask) async throws
    func disable(task: ScheduledTask) async throws
    func runNow(task: ScheduledTask) async throws -> TaskExecutionResult
    func isInstalled(task: ScheduledTask) async -> Bool
    func isRunning(task: ScheduledTask) async -> Bool
    func discoverTasks() async throws -> [ScheduledTask]
}

extension SchedulerService {
    func update(task: ScheduledTask) async throws {
        try await uninstall(task: task)
        try await install(task: task)
        if task.isEnabled {
            try await enable(task: task)
        }
    }
}

class SchedulerServiceFactory {
    static func service(for backend: SchedulerBackend) -> SchedulerService {
        switch backend {
        case .launchd:
            return LaunchdService.shared
        case .cron:
            return CronService.shared
        }
    }
}
