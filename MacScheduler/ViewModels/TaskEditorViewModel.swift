//
//  TaskEditorViewModel.swift
//  MacScheduler
//
//  ViewModel for creating and editing scheduled tasks.
//

import Foundation
import SwiftUI

@MainActor
class TaskEditorViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var taskDescription: String = ""
    @Published var backend: SchedulerBackend = .launchd
    @Published var actionType: TaskActionType = .executable
    @Published var executablePath: String = ""
    @Published var arguments: String = ""
    @Published var workingDirectory: String = ""
    @Published var scriptContent: String = ""
    @Published var triggerType: TriggerType = .onDemand
    @Published var scheduleMinute: Int = 0
    @Published var scheduleHour: Int = 0
    @Published var scheduleDay: Int? = nil
    @Published var scheduleWeekday: Int? = nil
    @Published var scheduleMonth: Int? = nil
    @Published var intervalValue: Int = 60
    @Published var intervalUnit: IntervalUnit = .minutes
    @Published var runAtLoad: Bool = false
    @Published var keepAlive: Bool = false
    @Published var standardOutPath: String = ""
    @Published var standardErrorPath: String = ""

    @Published var validationErrors: [String] = []
    @Published var showValidationErrors = false

    private var editingTask: ScheduledTask?

    var isEditing: Bool {
        editingTask != nil
    }

    var title: String {
        isEditing ? "Edit Task" : "New Task"
    }

    enum IntervalUnit: String, CaseIterable {
        case seconds = "Seconds"
        case minutes = "Minutes"
        case hours = "Hours"
        case days = "Days"

        var multiplier: Int {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
            case .hours: return 3600
            case .days: return 86400
            }
        }
    }

    init() {}

    init(task: ScheduledTask) {
        loadTask(task)
    }

    func loadTask(_ task: ScheduledTask) {
        editingTask = task
        name = task.name
        taskDescription = task.description
        backend = task.backend

        actionType = task.action.type
        workingDirectory = task.action.workingDirectory ?? ""
        scriptContent = task.action.scriptContent ?? ""

        // For shell scripts, extract the actual script path from arguments
        if task.action.type == .shellScript {
            let path = task.action.path
            if path.hasSuffix("bash") || path.hasSuffix("sh") || path.hasSuffix("zsh") {
                // The shell binary is in path, script path is in arguments
                if let scriptPath = task.action.arguments.first, !scriptPath.hasPrefix("-") {
                    executablePath = scriptPath
                    arguments = task.action.arguments.dropFirst().joined(separator: " ")
                } else {
                    executablePath = ""
                    arguments = task.action.arguments.joined(separator: " ")
                }
            } else {
                executablePath = path
                arguments = task.action.arguments.joined(separator: " ")
            }
        } else if task.action.type == .appleScript {
            let path = task.action.path
            if path.hasSuffix("osascript") {
                // osascript is in path, script path is in arguments
                if let scriptPath = task.action.arguments.first, !scriptPath.hasPrefix("-") {
                    executablePath = scriptPath
                    arguments = task.action.arguments.dropFirst().joined(separator: " ")
                } else {
                    executablePath = ""
                    arguments = task.action.arguments.joined(separator: " ")
                }
            } else {
                executablePath = path
                arguments = task.action.arguments.joined(separator: " ")
            }
        } else {
            executablePath = task.action.path
            arguments = task.action.arguments.joined(separator: " ")
        }

        triggerType = task.trigger.type

        if let schedule = task.trigger.calendarSchedule {
            scheduleMinute = schedule.minute ?? 0
            scheduleHour = schedule.hour ?? 0
            scheduleDay = schedule.day
            scheduleWeekday = schedule.weekday
            scheduleMonth = schedule.month
        }

        if let seconds = task.trigger.intervalSeconds {
            if seconds % 86400 == 0 {
                intervalUnit = .days
                intervalValue = seconds / 86400
            } else if seconds % 3600 == 0 {
                intervalUnit = .hours
                intervalValue = seconds / 3600
            } else if seconds % 60 == 0 {
                intervalUnit = .minutes
                intervalValue = seconds / 60
            } else {
                intervalUnit = .seconds
                intervalValue = seconds
            }
        }

        runAtLoad = task.runAtLoad
        keepAlive = task.keepAlive
        standardOutPath = task.standardOutPath ?? ""
        standardErrorPath = task.standardErrorPath ?? ""
    }

    func reset() {
        editingTask = nil
        name = ""
        taskDescription = ""
        backend = .launchd
        actionType = .executable
        executablePath = ""
        arguments = ""
        workingDirectory = ""
        scriptContent = ""
        triggerType = .onDemand
        scheduleMinute = 0
        scheduleHour = 0
        scheduleDay = nil
        scheduleWeekday = nil
        scheduleMonth = nil
        intervalValue = 60
        intervalUnit = .minutes
        runAtLoad = false
        keepAlive = false
        standardOutPath = ""
        standardErrorPath = ""
        validationErrors = []
        showValidationErrors = false
    }

    func validate() -> Bool {
        validationErrors = []

        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append("Task name is required")
        }

        switch actionType {
        case .executable:
            if executablePath.isEmpty {
                validationErrors.append("Executable path is required")
            }
        case .shellScript:
            if executablePath.isEmpty && scriptContent.isEmpty {
                validationErrors.append("Script path or content is required")
            }
        case .appleScript:
            if executablePath.isEmpty && scriptContent.isEmpty {
                validationErrors.append("AppleScript path or content is required")
            }
        }

        if backend == .cron && !triggerType.supportsCron {
            validationErrors.append("'\(triggerType.rawValue)' trigger is not supported by cron")
        }

        if triggerType == .interval && intervalValue <= 0 {
            validationErrors.append("Interval must be greater than 0")
        }

        showValidationErrors = !validationErrors.isEmpty
        return validationErrors.isEmpty
    }

    func buildTask() -> ScheduledTask {
        let action = TaskAction(
            id: editingTask?.action.id ?? UUID(),
            type: actionType,
            path: executablePath,
            arguments: arguments.isEmpty ? [] : arguments.components(separatedBy: " "),
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            environmentVariables: [:],
            scriptContent: scriptContent.isEmpty ? nil : scriptContent
        )

        var trigger: TaskTrigger
        switch triggerType {
        case .calendar:
            trigger = TaskTrigger(
                id: editingTask?.trigger.id ?? UUID(),
                type: .calendar,
                calendarSchedule: CalendarSchedule(
                    minute: scheduleMinute,
                    hour: scheduleHour,
                    day: scheduleDay,
                    weekday: scheduleWeekday,
                    month: scheduleMonth
                )
            )
        case .interval:
            trigger = TaskTrigger(
                id: editingTask?.trigger.id ?? UUID(),
                type: .interval,
                intervalSeconds: intervalValue * intervalUnit.multiplier
            )
        case .atLogin:
            trigger = .atLogin
        case .atStartup:
            trigger = .atStartup
        case .onDemand:
            trigger = .onDemand
        }

        return ScheduledTask(
            id: editingTask?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            description: taskDescription,
            backend: backend,
            action: action,
            trigger: trigger,
            status: editingTask?.status ?? TaskStatus(state: .enabled),
            createdAt: editingTask?.createdAt ?? Date(),
            modifiedAt: Date(),
            runAtLoad: runAtLoad,
            keepAlive: keepAlive,
            standardOutPath: standardOutPath.isEmpty ? nil : standardOutPath,
            standardErrorPath: standardErrorPath.isEmpty ? nil : standardErrorPath
        )
    }
}
