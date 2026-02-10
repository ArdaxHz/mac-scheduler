import Foundation
import IOKit
import Supabase
import SwiftUI

@MainActor
class LicenseService: ObservableObject {
    static let shared = LicenseService()

    @Published var licenseTier: LicenseTier = .none
    @Published var trialDaysRemaining: Int = 0
    @Published var isLicenseValid = false
    @Published var hasCloudSync = false
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The single source of truth for whether the user can interact with tasks.
    /// True if local trial is active OR user has a paid license (via account or device key).
    @Published var canPerformActions = false

    @AppStorage("cachedLicenseTier") private var cachedTierRaw: String = "none"
    @AppStorage("trialStartDate") private var trialStartDateRaw: Double = 0
    @AppStorage("activatedLicenseKey") private var activatedLicenseKey: String = ""

    private let client = SupabaseManager.shared.client
    private static let trialDurationDays = 7

    private init() {
        // Restore cached tier for offline grace
        licenseTier = LicenseTier(rawValue: cachedTierRaw) ?? .none
        isLicenseValid = licenseTier.hasAppAccess
        hasCloudSync = licenseTier.hasCloudSync
        updateCanPerformActions()
    }

    // MARK: - Device Info

    static var machineID: String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(platformExpert) }
        if let uuid = IORegistryEntryCreateCFProperty(platformExpert, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
            return uuid
        }
        // Stable fallback: generate a UUID once and persist it in Application Support.
        // Never use hostname — it's user-changeable and not unique.
        return stableFallbackDeviceId()
    }

    /// Generate and persist a stable device identifier as a fallback when IOPlatformUUID is unavailable.
    private static func stableFallbackDeviceId() -> String {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacScheduler")
        let idFile = appDir.appendingPathComponent(".device_id")

        // Read existing
        if let existing = try? String(contentsOf: idFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty {
            return existing
        }

        // Generate new
        let newId = "fallback-\(UUID().uuidString)"
        try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        try? newId.write(to: idFile, atomically: true, encoding: .utf8)
        // Restrict permissions to owner only
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: idFile.path)
        return newId
    }

    static var machineName: String {
        Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    static var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    // MARK: - Local Trial

    func startTrialIfNeeded() {
        if trialStartDateRaw == 0 {
            trialStartDateRaw = Date().timeIntervalSince1970
        }
        refreshLocalTrial()
    }

    func refreshLocalTrial() {
        guard trialStartDateRaw > 0 else {
            trialDaysRemaining = 0
            updateCanPerformActions()
            return
        }

        let startDate = Date(timeIntervalSince1970: trialStartDateRaw)
        let expiryDate = Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: startDate)!
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        trialDaysRemaining = max(0, remaining)

        if !licenseTier.hasAppAccess || licenseTier == .trial {
            licenseTier = trialDaysRemaining > 0 ? .trial : .expired
        }

        updateCanPerformActions()
    }

    var isLocalTrialActive: Bool {
        guard trialStartDateRaw > 0 else { return false }
        let startDate = Date(timeIntervalSince1970: trialStartDateRaw)
        let expiryDate = Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: startDate)!
        return Date() < expiryDate
    }

    var isLocalTrialExpired: Bool {
        trialStartDateRaw > 0 && !isLocalTrialActive
    }

    // MARK: - Device License Activation (no auth required)

    func activateDeviceWithKey(_ key: String) async throws {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let params: [String: String] = [
            "p_key": key,
            "p_machine_id": Self.machineID,
            "p_machine_name": Self.machineName,
            "p_os_version": Self.osVersion
        ]

        do {
            let response: DeviceActivationResponse = try await client
                .rpc("activate_device", params: params)
                .execute()
                .value

            if response.success {
                let tier = LicenseTier(rawValue: response.tier ?? "none") ?? .none
                licenseTier = tier
                isLicenseValid = tier.hasAppAccess
                hasCloudSync = tier.hasCloudSync
                cachedTierRaw = tier.rawValue
                activatedLicenseKey = key
                trialDaysRemaining = 0
                updateCanPerformActions()
            } else {
                errorMessage = response.error ?? "Failed to activate license"
                throw LicenseError.redemptionFailed(response.error ?? "Unknown error")
            }
        } catch let error as LicenseError {
            throw error
        } catch {
            errorMessage = Self.sanitizeLicenseError(error)
            throw error
        }
    }

    /// Re-validate a previously activated device key on launch.
    func restoreDeviceActivation() async {
        guard !activatedLicenseKey.isEmpty else { return }

        do {
            try await activateDeviceWithKey(activatedLicenseKey)
        } catch {
            // Use cached tier for offline grace
            isLicenseValid = licenseTier.hasAppAccess
            hasCloudSync = licenseTier.hasCloudSync
            updateCanPerformActions()
        }
    }

    // MARK: - Supabase Account License (requires auth)

    func checkLicenseStatus() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: LicenseStatusResponse = try await client
                .rpc("get_license_status")
                .execute()
                .value

            if response.success {
                let tier = LicenseTier(rawValue: response.tier ?? "none") ?? .none
                if tier == .pro || tier == .lifetime {
                    licenseTier = tier
                    isLicenseValid = true
                    hasCloudSync = true
                    cachedTierRaw = tier.rawValue
                }
            }
        } catch {
            isLicenseValid = licenseTier.hasAppAccess
            hasCloudSync = licenseTier.hasCloudSync
        }

        updateCanPerformActions()
    }

    func redeemLicenseKey(_ key: String) async throws {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let response: RedeemResponse = try await client
                .rpc("redeem_license_key", params: ["p_key": key])
                .execute()
                .value

            if response.success {
                let tier = LicenseTier(rawValue: response.tier ?? "none") ?? .none
                licenseTier = tier
                isLicenseValid = tier.hasAppAccess
                hasCloudSync = tier.hasCloudSync
                cachedTierRaw = tier.rawValue
                trialDaysRemaining = 0
                updateCanPerformActions()
            } else {
                errorMessage = response.error ?? "Failed to redeem license key"
                throw LicenseError.redemptionFailed(response.error ?? "Unknown error")
            }
        } catch let error as LicenseError {
            throw error
        } catch {
            errorMessage = Self.sanitizeLicenseError(error)
            throw error
        }
    }

    /// Map raw errors to user-friendly messages.
    private static func sanitizeLicenseError(_ error: Error) -> String {
        let message = error.localizedDescription.lowercased()
        if message.contains("network") || message.contains("connection") || message.contains("offline") {
            return "Network error. Please check your internet connection."
        }
        if message.contains("timeout") {
            return "Request timed out. Please try again."
        }
        if message.contains("rate limit") || message.contains("too many") {
            return "Too many attempts. Please wait and try again."
        }
        return "License activation failed. Please try again."
    }

    func reset() {
        let wasPaid = licenseTier == .pro || licenseTier == .lifetime
        if wasPaid && activatedLicenseKey.isEmpty {
            // Only reset account-based license, not device-based
            cachedTierRaw = "none"
        }
        isLicenseValid = false
        hasCloudSync = false
        refreshLocalTrial()
    }

    private func updateCanPerformActions() {
        let hasPaidLicense = licenseTier == .pro || licenseTier == .lifetime
        canPerformActions = isLocalTrialActive || hasPaidLicense
    }
}

enum LicenseError: LocalizedError {
    case redemptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .redemptionFailed(let message): return message
        }
    }
}

private struct LicenseStatusResponse: Decodable {
    let success: Bool
    let tier: String?
    let isValid: Bool?
    let trialDaysRemaining: Int?
    let hasCloudSync: Bool?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success, tier, error
        case isValid = "is_valid"
        case trialDaysRemaining = "trial_days_remaining"
        case hasCloudSync = "has_cloud_sync"
    }
}

private struct RedeemResponse: Decodable {
    let success: Bool
    let tier: String?
    let message: String?
    let error: String?
}

private struct DeviceActivationResponse: Decodable {
    let success: Bool
    let tier: String?
    let message: String?
    let error: String?
}
