//
//  MacSchedulerApp.swift
//  MacScheduler
//
//  A native macOS app for managing scheduled tasks using launchd and cron backends.
//

import SwiftUI

@main
struct MacSchedulerApp: App {
    @StateObject private var taskListViewModel = TaskListViewModel()
    @StateObject private var authService = AuthService.shared
    @StateObject private var licenseService = LicenseService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(taskListViewModel)
                .environmentObject(authService)
                .environmentObject(licenseService)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    Task { await TaskHistoryService.shared.flush() }
                }
                .onOpenURL { url in
                    guard url.scheme == "macscheduler", url.host == "auth" else { return }
                    Task { await authService.handleAuthCallback(url: url) }
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task") {
                    NotificationCenter.default.post(name: .createNewTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(authService)
                .environmentObject(licenseService)
        }
        #endif
    }
}

extension Notification.Name {
    static let createNewTask = Notification.Name("createNewTask")
}
