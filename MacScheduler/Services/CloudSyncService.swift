import Foundation
import Supabase

actor CloudSyncService {
    static let shared = CloudSyncService()

    private let client = SupabaseManager.shared.client

    private init() {}

    /// Per-app sync identifier. Uses a random UUID (not hardware serial) to avoid
    /// exposing real device fingerprints to the cloud backend.
    var deviceId: String {
        if let cached = UserDefaults.standard.string(forKey: "cloudSyncDeviceId") {
            return cached
        }

        let deviceId = UUID().uuidString
        UserDefaults.standard.set(deviceId, forKey: "cloudSyncDeviceId")
        return deviceId
    }

    func pushTask(_ task: ScheduledTask) async throws {
        let userId = try await currentUserId()

        let cloudTask = CloudTask(
            id: task.id,
            userId: userId,
            launchdLabel: task.launchdLabel,
            name: task.name,
            description: task.description,
            backend: task.backend.rawValue,
            actionConfig: CloudTask.ActionConfig(
                type: task.action.type.rawValue,
                path: task.action.path,
                arguments: task.action.arguments,
                workingDirectory: task.action.workingDirectory,
                scriptContent: task.action.scriptContent
            ),
            triggerConfig: encodeTriggerConfig(task.trigger),
            runAtLoad: task.runAtLoad,
            keepAlive: task.keepAlive,
            standardOutPath: task.standardOutPath,
            standardErrorPath: task.standardErrorPath,
            deviceId: deviceId,
            syncedAt: Date()
        )

        try await client
            .from("cloud_tasks")
            .upsert(cloudTask, onConflict: "user_id,launchd_label")
            .execute()
    }

    func pullTasks() async throws -> [CloudTask] {
        let userId = try await currentUserId()

        let tasks: [CloudTask] = try await client
            .from("cloud_tasks")
            .select()
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value

        return tasks
    }

    func deleteCloudTask(launchdLabel: String) async throws {
        let userId = try await currentUserId()

        try await client
            .from("cloud_tasks")
            .delete()
            .eq("user_id", value: userId.uuidString)
            .eq("launchd_label", value: launchdLabel)
            .execute()
    }

    private func currentUserId() async throws -> UUID {
        let session = try await client.auth.session
        return session.user.id
    }

    private func encodeTriggerConfig(_ trigger: TaskTrigger) -> CloudTask.TriggerConfig {
        var config = CloudTask.TriggerConfig()
        config.type = trigger.type.rawValue

        switch trigger.type {
        case .interval:
            config.interval = trigger.intervalSeconds
        case .calendar:
            if let cal = trigger.calendarSchedule {
                config.minute = cal.minute
                config.hour = cal.hour
                config.dayOfWeek = cal.weekday
                config.dayOfMonth = cal.day
                config.month = cal.month
            }
        case .atLogin, .atStartup, .onDemand:
            break
        }

        return config
    }
}
