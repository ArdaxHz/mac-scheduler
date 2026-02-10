import SwiftUI

struct AppRootView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var licenseService: LicenseService
    @EnvironmentObject var taskListViewModel: TaskListViewModel

    var body: some View {
        MainView()
            .environmentObject(taskListViewModel)
            .task {
                await initialize()
            }
    }

    private func initialize() async {
        licenseService.startTrialIfNeeded()

        // Restore device-based license (no auth needed)
        await licenseService.restoreDeviceActivation()

        // Silently restore auth session if one exists
        await authService.restoreSession()

        // If authenticated, also check account-based license
        if authService.isAuthenticated {
            await licenseService.checkLicenseStatus()
        }
    }
}
