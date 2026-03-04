//
//  VersionHistorySheet.swift
//  MacScheduler
//
//  View for displaying task version history and reverting to previous versions.
//

import SwiftUI

struct VersionHistorySheet: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    @Environment(\.dismiss) private var dismiss
    let task: ScheduledTask
    @State private var snapshots: [TaskSnapshot] = []
    @State private var selectedSnapshot: TaskSnapshot?
    @State private var snapshotContent: String?
    @State private var showRevertConfirmation = false
    @State private var snapshotToRevert: TaskSnapshot?

    var body: some View {
        NavigationStack {
            Group {
                if snapshots.isEmpty {
                    ContentUnavailableView {
                        Label("No Version History", systemImage: "clock.arrow.2.circlepath")
                    } description: {
                        Text("Version history will be recorded when this task is edited or deleted.")
                    }
                } else {
                    HStack(spacing: 0) {
                        snapshotList
                            .frame(width: 280)
                        Divider()
                        snapshotDetail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .navigationTitle("Version History — \(task.name)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 650, minHeight: 450)
        .task {
            snapshots = await TaskVersionService.shared.getSnapshots(for: task.launchdLabel)
        }
        .onChange(of: selectedSnapshot) { _, newSnapshot in
            if let snapshot = newSnapshot {
                loadContent(for: snapshot)
            } else {
                snapshotContent = nil
            }
        }
        .confirmationDialog("Revert to This Version?", isPresented: $showRevertConfirmation) {
            Button("Revert", role: .destructive) {
                if let snapshot = snapshotToRevert {
                    Task {
                        await viewModel.revertTask(task, to: snapshot)
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                snapshotToRevert = nil
            }
        } message: {
            Text("This will replace the current task configuration with the selected version. The current version will be saved to version history first.")
        }
    }

    private var snapshotList: some View {
        List(snapshots, selection: $selectedSnapshot) { snapshot in
            SnapshotRow(snapshot: snapshot)
                .tag(snapshot)
        }
    }

    @ViewBuilder
    private var snapshotDetail: some View {
        if let snapshot = selectedSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.taskName)
                            .font(.headline)
                        Text(snapshot.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        reasonBadge(snapshot.reason)
                    }
                    Spacer()
                    Button("Revert to This Version") {
                        snapshotToRevert = snapshot
                        showRevertConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(task.isReadOnly)
                }
                .padding(.horizontal)
                .padding(.top)

                if let content = snapshotContent {
                    ScrollView {
                        Text(content)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding()
                    }
                    .background(Color(.textBackgroundColor))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom)
                } else {
                    ContentUnavailableView {
                        Label("Content Unavailable", systemImage: "doc.questionmark")
                    } description: {
                        Text("The snapshot file could not be read.")
                    }
                    .padding()
                }
            }
        } else {
            ContentUnavailableView {
                Label("Select a Version", systemImage: "clock.arrow.2.circlepath")
            } description: {
                Text("Select a version from the list to view its content.")
            }
        }
    }

    private func loadContent(for snapshot: TaskSnapshot) {
        Task {
            snapshotContent = await TaskVersionService.shared.readSnapshotContent(snapshot)
        }
    }

    private func reasonBadge(_ reason: TaskSnapshot.SnapshotReason) -> some View {
        Text(reason == .beforeEdit ? "Before Edit" : "Before Delete")
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(reason == .beforeEdit ? Color.blue.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundColor(reason == .beforeEdit ? .blue : .red)
            .cornerRadius(4)
    }
}

private struct SnapshotRow: View {
    let snapshot: TaskSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            HStack(spacing: 6) {
                Text(snapshot.reason == .beforeEdit ? "Before Edit" : "Before Delete")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(snapshot.reason == .beforeEdit ? Color.blue.opacity(0.2) : Color.red.opacity(0.2))
                    .foregroundColor(snapshot.reason == .beforeEdit ? .blue : .red)
                    .cornerRadius(4)

                if let newLabel = snapshot.newLabel {
                    Text("→ \(newLabel)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Text(snapshot.taskName)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

extension TaskSnapshot: Hashable {
    static func == (lhs: TaskSnapshot, rhs: TaskSnapshot) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
