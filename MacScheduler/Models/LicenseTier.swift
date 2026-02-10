import Foundation

enum LicenseTier: String, Codable, CaseIterable {
    case none
    case trial
    case expired
    case pro
    case lifetime

    var hasAppAccess: Bool {
        switch self {
        case .trial, .pro, .lifetime:
            return true
        case .none, .expired:
            return false
        }
    }

    var hasCloudSync: Bool {
        switch self {
        case .pro, .lifetime:
            return true
        case .none, .trial, .expired:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .none: return "No License"
        case .trial: return "Free Trial"
        case .expired: return "Trial Expired"
        case .pro: return "Pro"
        case .lifetime: return "Lifetime"
        }
    }

    var badgeColor: String {
        switch self {
        case .none, .expired: return "red"
        case .trial: return "orange"
        case .pro: return "blue"
        case .lifetime: return "purple"
        }
    }
}
