import Foundation

struct UserProfile: Codable {
    let id: UUID
    let email: String
    var displayName: String?
    var licenseTier: String
    var trialStartedAt: Date?
    var trialExpiresAt: Date?
    var licenseKeyId: UUID?
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email
        case displayName = "display_name"
        case licenseTier = "license_tier"
        case trialStartedAt = "trial_started_at"
        case trialExpiresAt = "trial_expires_at"
        case licenseKeyId = "license_key_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var tier: LicenseTier {
        LicenseTier(rawValue: licenseTier) ?? .none
    }
}
