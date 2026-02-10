import Foundation

struct CloudTask: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var launchdLabel: String
    var name: String
    var description: String
    var backend: String
    var actionConfig: ActionConfig
    var triggerConfig: TriggerConfig
    var runAtLoad: Bool
    var keepAlive: Bool
    var standardOutPath: String?
    var standardErrorPath: String?
    var deviceId: String
    var syncedAt: Date?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case launchdLabel = "launchd_label"
        case name, description, backend
        case actionConfig = "action_config"
        case triggerConfig = "trigger_config"
        case runAtLoad = "run_at_load"
        case keepAlive = "keep_alive"
        case standardOutPath = "standard_out_path"
        case standardErrorPath = "standard_error_path"
        case deviceId = "device_id"
        case syncedAt = "synced_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    struct ActionConfig: Codable {
        var type: String?
        var path: String?
        var arguments: [String]?
        var workingDirectory: String?
        var scriptContent: String?
    }

    struct TriggerConfig: Codable {
        var type: String?
        var interval: Int?
        var minute: Int?
        var hour: Int?
        var dayOfWeek: Int?
        var dayOfMonth: Int?
        var month: Int?
        var cronExpression: String?

        enum CodingKeys: String, CodingKey {
            case type, interval, minute, hour
            case dayOfWeek = "day_of_week"
            case dayOfMonth = "day_of_month"
            case month
            case cronExpression = "cron_expression"
        }
    }
}

enum CloudSyncStatus: String, Codable {
    case synced
    case localOnly
    case modified
    case cloudNewer
}
