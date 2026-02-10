import SwiftUI

struct LicenseActivationView: View {
    @EnvironmentObject var licenseService: LicenseService
    @Environment(\.dismiss) private var dismiss

    @State private var licenseKey = ""
    @State private var showError = false
    @State private var errorText = ""
    @State private var showSuccess = false
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: trialActive ? "clock.badge.checkmark" : "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(trialActive ? .orange : .red)

                Text(trialActive ? "Free Trial Active" : "Trial Expired")
                    .font(.title)
                    .fontWeight(.bold)

                if trialActive {
                    Text("\(licenseService.trialDaysRemaining) day\(licenseService.trialDaysRemaining == 1 ? "" : "s") remaining")
                        .font(.headline)
                        .foregroundColor(.orange)
                } else {
                    Text("Enter a license key to continue using the app")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // License key input
            VStack(alignment: .leading, spacing: 8) {
                Text("License Key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("MS-LIFETIME-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .disableAutocorrection(true)
            }

            // Activate button
            Button {
                activate()
            } label: {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("Activate License")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(licenseKey.isEmpty || isSubmitting)

            if showSuccess {
                Label("License activated! Tier: \(licenseService.licenseTier.displayName)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(32)
        .frame(width: 400)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorText)
        }
    }

    private var trialActive: Bool {
        licenseService.licenseTier == .trial && licenseService.trialDaysRemaining > 0
    }

    private func activate() {
        isSubmitting = true
        showSuccess = false
        Task {
            do {
                try await licenseService.activateDeviceWithKey(licenseKey)
                showSuccess = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            } catch {
                errorText = error.localizedDescription
                showError = true
            }
            isSubmitting = false
        }
    }
}
