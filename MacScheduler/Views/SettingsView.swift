//
//  SettingsView.swift
//  MacScheduler
//
//  Settings/preferences panel for the app.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var licenseService: LicenseService

    @AppStorage("defaultBackend") private var defaultBackend = SchedulerBackend.launchd.rawValue
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @AppStorage("logRetentionDays") private var logRetentionDays = 30
    @AppStorage("scriptsDirectory") private var scriptsDirectory = ""
    @State private var showDirectoryPicker = false
    @State private var showResetConfirmation = false
    @State private var updateCheckState: UpdateCheckState = .idle
    @State private var availableUpdate: UpdateService.Release?
    @State private var versionTapCount = 0
    @State private var showHiddenLicense = false
    @State private var hiddenLicenseKey = ""
    @State private var hiddenLicenseActivating = false
    @State private var hiddenLicenseError = ""
    @State private var hiddenLicenseSuccess = false

    enum UpdateCheckState {
        case idle, checking, upToDate, updateAvailable, error
    }

    private var defaultScriptsDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Scripts"
    }

    private var displayScriptsDirectory: String {
        scriptsDirectory.isEmpty ? defaultScriptsDirectory : scriptsDirectory
    }

    var body: some View {
        TabView {
            AccountSettingsView()
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            storageSettings
                .tabItem {
                    Label("Storage", systemImage: "folder")
                }

            advancedSettings
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }

            aboutSettings
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 420)
        .confirmationDialog("Reset App", isPresented: $showResetConfirmation) {
            Button("Reset Everything", role: .destructive) {
                resetApp()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all tasks, execution history, and remove all MacScheduler LaunchAgent plists. This cannot be undone.")
        }
    }

    private func resetApp() {
        let fm = FileManager.default

        // Remove app data directory (execution history, scripts)
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("MacScheduler")
        try? fm.removeItem(at: appDir)

        // Reset UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
    }

    private var generalSettings: some View {
        Form {
            Section {
                Picker("Default Backend", selection: $defaultBackend) {
                    ForEach(SchedulerBackend.allCases, id: \.rawValue) { backend in
                        Text(backend.displayName).tag(backend.rawValue)
                    }
                }
                .help("The default scheduler backend for new tasks")

                Toggle("Show Notifications", isOn: $showNotifications)
                    .help("Show notifications when tasks complete")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var storageSettings: some View {
        Form {
            Section("Scripts Directory") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Where new scripts created by Mac Task Scheduler will be stored:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(displayScriptsDirectory)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.textBackgroundColor))
                            .cornerRadius(6)

                        Button("Choose...") {
                            showDirectoryPicker = true
                        }
                        .help("Choose a custom scripts directory")

                        Button("Reset") {
                            scriptsDirectory = ""
                        }
                        .disabled(scriptsDirectory.isEmpty)
                        .help("Reset to default ~/Library/Scripts/")
                    }

                    Button("Open in Finder") {
                        let url = URL(fileURLWithPath: displayScriptsDirectory)
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.link)
                    .help("Open scripts directory in Finder")
                }
            }

            Section("Data Locations") {
                VStack(alignment: .leading, spacing: 8) {
                    LocationRow(
                        label: "User Launch Agents",
                        path: "~/Library/LaunchAgents/"
                    )

                    LocationRow(
                        label: "System Launch Agents",
                        path: "/Library/LaunchAgents/"
                    )

                    LocationRow(
                        label: "System Daemons",
                        path: "/Library/LaunchDaemons/"
                    )

                    LocationRow(
                        label: "Execution History",
                        path: "~/Library/Application Support/MacScheduler/history.json"
                    )
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .fileImporter(
            isPresented: $showDirectoryPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                scriptsDirectory = url.path
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var aboutSettings: some View {
        Form {
            Section("Application") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(appVersion) (\(buildNumber))")
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    versionTapCount += 1
                    if versionTapCount >= 5 {
                        withAnimation {
                            showHiddenLicense = true
                        }
                    }
                }

                HStack {
                    Text("macOS Requirement")
                    Spacer()
                    Text("14.0 (Sonoma)+")
                        .foregroundColor(.secondary)
                }
            }

            if showHiddenLicense {
                Section("Activate License") {
                    HStack {
                        TextField("License Key", text: $hiddenLicenseKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            activateHiddenLicense()
                        } label: {
                            if hiddenLicenseActivating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Activate")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(hiddenLicenseKey.isEmpty || hiddenLicenseActivating)
                    }

                    if hiddenLicenseSuccess {
                        Label("License activated: \(licenseService.licenseTier.displayName)", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }

                    if !hiddenLicenseError.isEmpty {
                        Label(hiddenLicenseError, systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }

            Section("Updates") {
                HStack {
                    switch updateCheckState {
                    case .idle:
                        Text("Check for updates to see if a new version is available.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                        Text("Checking for updates...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .upToDate:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("You're up to date (v\(appVersion))")
                            .font(.caption)
                    case .updateAvailable:
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundColor(.blue)
                        if let update = availableUpdate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Version \(update.version) is available")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                if !update.body.isEmpty {
                                    Text(update.body)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    case .error:
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Could not check for updates")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                Toggle("Automatically check for updates on launch", isOn: $autoCheckUpdates)
                    .help("When enabled, the app checks GitHub for new releases each time it launches")

                HStack {
                    Button("Check for Updates") {
                        checkForUpdate()
                    }
                    .disabled(updateCheckState == .checking)
                    .help("Check GitHub for a newer release")

                    if case .updateAvailable = updateCheckState, let update = availableUpdate {
                        Button("Download") {
                            if let url = URL(string: update.htmlURL) {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .help("Open the release page in your browser")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func activateHiddenLicense() {
        hiddenLicenseActivating = true
        hiddenLicenseError = ""
        hiddenLicenseSuccess = false
        Task {
            do {
                try await licenseService.activateDeviceWithKey(hiddenLicenseKey)
                hiddenLicenseSuccess = true
                hiddenLicenseKey = ""
            } catch {
                hiddenLicenseError = error.localizedDescription
            }
            hiddenLicenseActivating = false
        }
    }

    private func checkForUpdate() {
        updateCheckState = .checking
        Task {
            let release = await UpdateService.shared.checkForUpdate()
            if let release = release {
                availableUpdate = release
                updateCheckState = .updateAvailable
            } else {
                updateCheckState = .upToDate
            }
        }
    }

    private var advancedSettings: some View {
        Form {
            Section {
                Picker("Log Retention", selection: $logRetentionDays) {
                    Text("7 days").tag(7)
                    Text("14 days").tag(14)
                    Text("30 days").tag(30)
                    Text("90 days").tag(90)
                    Text("Forever").tag(0)
                }
                .help("How long to keep task execution history")
            }

            Section("Danger Zone") {
                Button("Clear All History", role: .destructive) {
                    Task {
                        await TaskHistoryService.shared.clearAllHistory()
                    }
                }
                .help("Delete all task execution history permanently")

                Button("Reset App", role: .destructive) {
                    showResetConfirmation = true
                }
                .help("Delete all app data and reset to factory defaults")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct LocationRow: View {
    let label: String
    let path: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(path)
                    .font(.system(.caption, design: .monospaced))
            }
            Spacer()
            Button {
                let expandedPath = NSString(string: path).expandingTildeInPath
                let url = URL(fileURLWithPath: expandedPath)
                if FileManager.default.fileExists(atPath: expandedPath) {
                    NSWorkspace.shared.selectFile(expandedPath, inFileViewerRootedAtPath: "")
                } else {
                    NSWorkspace.shared.open(url.deletingLastPathComponent())
                }
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder")
        }
    }
}

#Preview {
    SettingsView()
}
