//
//  SettingsView.swift
//  MacScheduler
//
//  Settings/preferences panel for the app.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultBackend") private var defaultBackend = SchedulerBackend.launchd.rawValue
    @AppStorage("showNotifications") private var showNotifications = true
    @AppStorage("logRetentionDays") private var logRetentionDays = 30
    @AppStorage("scriptsDirectory") private var scriptsDirectory = ""
    @State private var showDirectoryPicker = false

    private var defaultScriptsDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/MacScheduler/Scripts"
    }

    private var displayScriptsDirectory: String {
        scriptsDirectory.isEmpty ? defaultScriptsDirectory : scriptsDirectory
    }

    var body: some View {
        TabView {
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
        .frame(width: 550, height: 350)
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

                        Button("Reset") {
                            scriptsDirectory = ""
                        }
                        .disabled(scriptsDirectory.isEmpty)
                    }

                    Button("Open in Finder") {
                        let url = URL(fileURLWithPath: displayScriptsDirectory)
                        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(url)
                    }
                    .buttonStyle(.link)
                }
            }

            Section("Data Locations") {
                VStack(alignment: .leading, spacing: 8) {
                    LocationRow(
                        label: "Tasks Database",
                        path: "~/Library/Application Support/MacScheduler/tasks.json"
                    )

                    LocationRow(
                        label: "Execution History",
                        path: "~/Library/Application Support/MacScheduler/history.json"
                    )

                    LocationRow(
                        label: "Launchd Plists",
                        path: "~/Library/LaunchAgents/"
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

                HStack {
                    Text("macOS Requirement")
                    Spacer()
                    Text("14.0 (Sonoma)+")
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
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
                .help("Delete all task execution history")
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
        }
    }
}

#Preview {
    SettingsView()
}
