//
//  DockerEditorView.swift
//  MacScheduler
//
//  Form for creating and editing Docker containers.
//

import SwiftUI

struct DockerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editorViewModel = DockerEditorViewModel()

    let task: ScheduledTask?
    let onSave: (ScheduledTask) -> Void
    @State private var showEnvFilePicker = false

    init(task: ScheduledTask? = nil, onSave: @escaping (ScheduledTask) -> Void) {
        self.task = task
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                imageSection
                containerNameSection
                portMappingsSection
                envVarsSection
                volumesSection
                restartPolicySection
                networkSection
                commandSection

                if editorViewModel.isEditing && editorViewModel.requiresRecreation {
                    recreationWarning
                }
            }
            .formStyle(.grouped)
            .navigationTitle(editorViewModel.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .help("Discard changes and close")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(editorViewModel.imageName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Save container configuration")
                }
            }
            .alert("Validation Errors", isPresented: $editorViewModel.showValidationErrors) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(editorViewModel.validationErrors.joined(separator: "\n"))
            }
            .onAppear {
                if let task = task {
                    editorViewModel.loadTask(task)
                } else {
                    editorViewModel.reset()
                }
            }
            .fileImporter(
                isPresented: $showEnvFilePicker,
                allowedContentTypes: [.plainText],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    editorViewModel.importEnvFile(from: url)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 550)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let ext = url.pathExtension.lowercased()
                let name = url.lastPathComponent.lowercased()
                if name.hasPrefix(".env") || ext == "env" {
                    DispatchQueue.main.async {
                        editorViewModel.importEnvFile(from: url)
                    }
                }
            }
            return true
        }
    }

    // MARK: - Sections

    private var imageSection: some View {
        Section("Image") {
            TextField("Image (e.g. nginx:latest)", text: $editorViewModel.imageName)
                .font(.system(.body, design: .monospaced))
                .help("Docker image name with optional tag. Required.")
        }
    }

    private var containerNameSection: some View {
        Section("Container Name") {
            TextField("Container name (optional)", text: $editorViewModel.containerName)
                .font(.system(.body, design: .monospaced))
                .help("Optional. Must start with alphanumeric, then alphanumeric + '_', '.', '-'. If empty, Docker assigns a random name.")
        }
    }

    private var portMappingsSection: some View {
        Section {
            ForEach($editorViewModel.portMappings) { $mapping in
                HStack(spacing: 8) {
                    TextField("Host", text: $mapping.hostPort)
                        .frame(minWidth: 60, maxWidth: 120)
                        .textFieldStyle(.roundedBorder)
                        .help("Host port (1-65535)")
                    Text(":")
                        .foregroundColor(.secondary)
                    TextField("Container", text: $mapping.containerPort)
                        .frame(minWidth: 60, maxWidth: 120)
                        .textFieldStyle(.roundedBorder)
                        .help("Container port (1-65535)")
                    Text("/")
                        .foregroundColor(.secondary)
                    Picker("", selection: $mapping.proto) {
                        Text("tcp").tag("tcp")
                        Text("udp").tag("udp")
                    }
                    .labelsHidden()
                    .frame(width: 70)

                    Spacer()

                    Button(role: .destructive) {
                        editorViewModel.portMappings.removeAll { $0.id == mapping.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this port mapping")
                }
            }

            Button {
                editorViewModel.portMappings.append(DockerEditorViewModel.PortMapping())
            } label: {
                Label("Add Port Mapping", systemImage: "plus.circle")
            }
        } header: {
            Text("Port Mappings")
        }
    }

    private var envVarsSection: some View {
        Section {
            if !editorViewModel.envVars.isEmpty {
                HStack(spacing: 8) {
                    Text("Key")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 100, alignment: .leading)
                    Text("")
                        .frame(width: 10)
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 100, alignment: .leading)
                    Spacer()
                }
            }

            ForEach($editorViewModel.envVars) { $env in
                HStack(spacing: 8) {
                    TextField("e.g. NODE_ENV", text: $env.key)
                        .frame(minWidth: 100)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("=")
                        .foregroundColor(.secondary)
                    TextField("e.g. production", text: $env.value)
                        .frame(minWidth: 100)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Spacer()

                    Button(role: .destructive) {
                        editorViewModel.envVars.removeAll { $0.id == env.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this environment variable")
                }
            }

            HStack {
                Button {
                    editorViewModel.envVars.append(DockerEditorViewModel.EnvVar())
                } label: {
                    Label("Add Environment Variable", systemImage: "plus.circle")
                }

                Spacer()

                Button {
                    showEnvFilePicker = true
                } label: {
                    Label("Import .env File", systemImage: "doc.badge.plus")
                }
            }
        } header: {
            Text("Environment Variables")
        }
    }

    private var volumesSection: some View {
        Section {
            ForEach($editorViewModel.volumeMounts) { $mount in
                HStack(spacing: 8) {
                    TextField("Host path", text: $mount.hostPath)
                        .frame(minWidth: 120)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text(":")
                        .foregroundColor(.secondary)
                    TextField("Container path", text: $mount.containerPath)
                        .frame(minWidth: 120)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))

                    Spacer()

                    Button(role: .destructive) {
                        editorViewModel.volumeMounts.removeAll { $0.id == mount.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Remove this volume mount")
                }
            }

            Button {
                editorViewModel.volumeMounts.append(DockerEditorViewModel.VolumeMount())
            } label: {
                Label("Add Volume Mount", systemImage: "plus.circle")
            }
        } header: {
            Text("Volume Mounts")
        }
    }

    private var restartPolicySection: some View {
        Section("Restart Policy") {
            Picker("Policy", selection: $editorViewModel.restartPolicy) {
                ForEach(DockerRestartPolicy.allCases, id: \.self) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .help("'Always' and 'Unless Stopped' will auto-start the container on boot")
        }
    }

    private var networkSection: some View {
        Section("Network") {
            TextField("Network mode (default: bridge)", text: $editorViewModel.networkMode)
                .font(.system(.body, design: .monospaced))
                .help("Docker network to connect to. Common values: bridge, host, none")
        }
    }

    private var commandSection: some View {
        Section("Command Override") {
            TextField("Command (optional)", text: $editorViewModel.commandOverride)
                .font(.system(.body, design: .monospaced))
                .help("Override the default command. Leave empty to use the image's default CMD.")
        }
    }

    private var recreationWarning: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Container Recreation Required")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)
                    Text("Changes to image, ports, environment, volumes, network, or command require the container to be stopped, removed, and recreated. Data in non-mounted volumes will be lost.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func save() {
        guard editorViewModel.validate() else { return }
        let task = editorViewModel.buildTask()
        onSave(task)
        dismiss()
    }
}

#Preview {
    DockerEditorView(onSave: { _ in })
}
