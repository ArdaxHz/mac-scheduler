//
//  DockerRemoveSheet.swift
//  MacScheduler
//
//  Cascade removal confirmation dialog for Docker containers.
//

import SwiftUI

struct DockerRemoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TaskListViewModel

    let task: ScheduledTask

    @State private var removeVolumes = false
    @State private var removeImage = false
    @State private var composeDown = false

    private var hasComposeProject: Bool {
        task.containerInfo?.composeProject != nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Remove Container")
                            .font(.headline)
                        Text(task.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Container info
                VStack(alignment: .leading, spacing: 8) {
                    if let info = task.containerInfo {
                        InfoRow(label: "Container ID", value: info.containerId, monospaced: true)
                        InfoRow(label: "Image", value: info.imageName, monospaced: true)
                        InfoRow(label: "Status", value: info.containerStatus)
                    }
                }

                Divider()

                // Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Removal Options")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Toggle(isOn: $removeVolumes) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remove attached volumes")
                            Text("Deletes anonymous volumes associated with this container")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle(isOn: $removeImage) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Remove image")
                            if let info = task.containerInfo {
                                Text("Deletes \(info.imageName) from local storage")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    if hasComposeProject {
                        Toggle(isOn: $composeDown) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Compose down")
                                if let project = task.containerInfo?.composeProject {
                                    Text("Stops and removes all containers in the '\(project)' project")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onChange(of: composeDown) { _, isOn in
                            if isOn {
                                // Compose down replaces individual removal
                                removeImage = false
                            }
                        }
                    }
                }

                Spacer()

                // Buttons
                HStack {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)

                    Spacer()

                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteDockerContainer(
                                task: task,
                                removeVolumes: removeVolumes,
                                removeImage: removeImage,
                                composeDown: composeDown
                            )
                            dismiss()
                        }
                    } label: {
                        Label(composeDown ? "Compose Down" : "Remove", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
            .navigationTitle("Remove Container")
        }
        .frame(width: 450, height: hasComposeProject ? 480 : 420)
    }
}
