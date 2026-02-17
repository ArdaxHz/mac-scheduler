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
    case dockerNotAvailable(String)
    case dockerCommandFailed(String)
    case dockerOperationNotSupported(String)
    case vmNotAvailable(String)
    case vmCommandFailed(String)
    case vmOperationNotSupported(String)

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
        case .dockerNotAvailable(let reason):
            return "Docker not available: \(reason)"
        case .dockerCommandFailed(let reason):
            return "Docker command failed: \(reason)"
        case .dockerOperationNotSupported(let reason):
            return "Docker operation not supported: \(reason)"
        case .vmNotAvailable(let reason):
            return "VM tool not available: \(reason)"
        case .vmCommandFailed(let reason):
            return "VM command failed: \(reason)"
        case .vmOperationNotSupported(let reason):
            return "VM operation not supported: \(reason)"
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
        case .docker:
            return DockerService.shared
        case .parallels:
            return ParallelsService.shared
        case .virtualBox:
            return VirtualBoxService.shared
        case .utm:
            return UTMService.shared
        case .vmwareFusion:
            return VMwareFusionService.shared
        }
    }
}
