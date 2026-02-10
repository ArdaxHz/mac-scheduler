import SwiftUI

struct AccountSettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var licenseService: LicenseService

    @State private var licenseKey = ""
    @State private var showLicenseInput = false
    @State private var showError = false
    @State private var errorText = ""
    @State private var isActivating = false
    @State private var isSyncing = false
    @AppStorage("cloudSyncEnabled") private var cloudSyncEnabled = false
    @State private var lastSyncTime: Date?

    var body: some View {
        Form {
            accountSection
            licenseSection
            cloudSyncSection
        }
        .formStyle(.grouped)
        .padding()
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var accountSection: some View {
        Section("Account") {
            if authService.isAuthenticated {
                HStack {
                    Text("Email")
                    Spacer()
                    Text(authService.currentUser?.email ?? "Unknown")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Text("Status")
                    Spacer()
                    Text("Not signed in")
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("License")
                Spacer()
                licenseBadge
            }

            if licenseService.licenseTier == .trial {
                HStack {
                    Text("Trial Expires In")
                    Spacer()
                    Text("\(licenseService.trialDaysRemaining) day\(licenseService.trialDaysRemaining == 1 ? "" : "s")")
                        .foregroundColor(.orange)
                }
            }

            if authService.isAuthenticated {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                        licenseService.reset()
                    }
                }
            }
        }
    }

    private var licenseBadge: some View {
        Text(licenseService.licenseTier.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierColor.opacity(0.2))
            .foregroundColor(tierColor)
            .cornerRadius(6)
    }

    private var tierColor: Color {
        switch licenseService.licenseTier {
        case .lifetime: return .purple
        case .pro: return .blue
        case .trial: return .orange
        case .expired, .none: return .red
        }
    }

    private var licenseSection: some View {
        Section("License Key") {
            if showLicenseInput {
                HStack {
                    TextField("MS-LIFETIME-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Button {
                        activateLicense()
                    } label: {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Activate")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(licenseKey.isEmpty || isActivating)

                    Button("Cancel") {
                        showLicenseInput = false
                        licenseKey = ""
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button("Enter License Key") {
                    showLicenseInput = true
                }
            }
        }
    }

    private var cloudSyncSection: some View {
        Section("Cloud Sync") {
            if licenseService.hasCloudSync {
                Toggle("Enable Cloud Sync", isOn: $cloudSyncEnabled)
                    .help("Sync task configurations across your Macs")

                if cloudSyncEnabled {
                    if let lastSync = lastSyncTime {
                        HStack {
                            Text("Last Synced")
                            Spacer()
                            Text(lastSync.formatted(date: .abbreviated, time: .shortened))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button {
                        syncNow()
                    } label: {
                        HStack {
                            if isSyncing {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sync Now")
                        }
                    }
                    .disabled(isSyncing)
                }
            } else {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                    Text("Cloud sync requires a Pro or Lifetime license")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func activateLicense() {
        isActivating = true
        Task {
            do {
                try await licenseService.redeemLicenseKey(licenseKey)
                showLicenseInput = false
                licenseKey = ""
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
            isActivating = false
        }
    }

    private func syncNow() {
        isSyncing = true
        Task {
            // Pull cloud tasks (sync logic happens at the view model level)
            do {
                _ = try await CloudSyncService.shared.pullTasks()
                lastSyncTime = Date()
            } catch {
                errorText = "Sync failed: \(error.localizedDescription)"
                showError = true
            }
            isSyncing = false
        }
    }
}
