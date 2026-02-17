//
//  DockerDetailSheet.swift
//  MacScheduler
//
//  Modal for inspecting Docker objects with rich detail.
//

import SwiftUI

enum DockerDetailType: Identifiable {
    case composeConfig(String)         // project name
    case imageInspect(String)          // image name
    case volumeInspect([String])       // volume names
    case launchOriginDetail(ContainerInfo)

    var id: String {
        switch self {
        case .composeConfig(let p): return "compose-\(p)"
        case .imageInspect(let i): return "image-\(i)"
        case .volumeInspect(let v): return "volume-\(v.joined(separator: ","))"
        case .launchOriginDetail(let c): return "origin-\(c.containerId)"
        }
    }
}

struct DockerDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let detailType: DockerDetailType

    @State private var content: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else {
                    ScrollView {
                        Text(content)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }

                if !content.isEmpty {
                    ToolbarItem(placement: .automatic) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(content, forType: .string)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .help("Copy output to clipboard")
                    }
                }
            }
        }
        .frame(minWidth: 550, minHeight: 400)
        .task {
            await loadContent()
        }
    }

    private var title: String {
        switch detailType {
        case .composeConfig(let project): return "Compose Config — \(project)"
        case .imageInspect(let image): return "Image — \(image)"
        case .volumeInspect(let volumes): return "Volumes — \(volumes.joined(separator: ", "))"
        case .launchOriginDetail: return "Launch Origin Detail"
        }
    }

    private func loadContent() async {
        isLoading = true
        defer { isLoading = false }

        let docker = DockerService.shared

        do {
            switch detailType {
            case .composeConfig(let project):
                content = try await docker.composeConfig(projectName: project)

            case .imageInspect(let image):
                content = try await docker.inspectImage(image)

            case .volumeInspect(let volumes):
                content = try await docker.inspectVolumes(volumes)

            case .launchOriginDetail(let info):
                // Build a summary of launch origin details
                var lines: [String] = []
                lines.append("Container: \(info.containerName)")
                lines.append("Container ID: \(info.containerId)")
                lines.append("Image: \(info.imageName)")
                lines.append("Launch Origin: \(info.launchOrigin.rawValue)")
                lines.append("Runtime: \(info.runtime.rawValue)")
                lines.append("Restart Policy: \(info.restartPolicy)")
                lines.append("Status: \(info.containerStatus)")
                if let project = info.composeProject {
                    lines.append("Compose Project: \(project)")
                }
                if let service = info.composeService {
                    lines.append("Compose Service: \(service)")
                }
                if let network = info.networkMode {
                    lines.append("Network Mode: \(network)")
                }
                if let created = info.createdAt {
                    lines.append("Created: \(created.formatted(date: .abbreviated, time: .shortened))")
                }
                if !info.ports.isEmpty {
                    lines.append("\nPorts:")
                    for port in info.ports {
                        lines.append("  \(port)")
                    }
                }
                if !info.volumes.isEmpty {
                    lines.append("\nVolumes:")
                    for vol in info.volumes {
                        lines.append("  \(vol)")
                    }
                }
                if let entrypoint = info.entrypoint, !entrypoint.isEmpty {
                    lines.append("\nEntrypoint: \(entrypoint.joined(separator: " "))")
                }
                if !info.command.isEmpty {
                    lines.append("Command: \(info.command.joined(separator: " "))")
                }
                if !info.environmentVariables.isEmpty {
                    lines.append("\nEnvironment Variables:")
                    for (key, value) in info.environmentVariables.sorted(by: { $0.key < $1.key }) {
                        lines.append("  \(key)=\(value)")
                    }
                }
                content = lines.joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
