//
//  TrashView.swift
//  MacScheduler
//
//  View for displaying and restoring deleted tasks.
//

import SwiftUI

struct TrashView: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    @State private var deletedSnapshots: [TaskSnapshot] = []
    @State private var showEmptyTrashConfirmation = false
    @State private var showPermanentDeleteConfirmation = false
    @State private var snapshotToPermanentlyDelete: TaskSnapshot?
    @State private var selectedSnapshot: TaskSnapshot?
    @State private var snapshotContent: String?

    var body: some View {
        VStack(spacing: 0) {
            if deletedSnapshots.isEmpty {
                ContentUnavailableView {
                    Label("Trash is Empty", systemImage: "trash")
                } description: {
                    Text("Deleted tasks will appear here. You can restore them or permanently delete them.")
                }
            } else {
                HSplitView {
                    trashList
                        .frame(minWidth: 250, maxWidth: 350)
                    trashDetail
                        .frame(minWidth: 300)
                }
            }
        }
        .navigationTitle("Trash")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await loadDeletedSnapshots() }
                } label: {
                    Label("Refresh", systemImage: "arrow.triangle.2.circlepath")
                }
                .help("Refresh trash")

                Button(role: .destructive) {
                    showEmptyTrashConfirmation = true
                } label: {
                    Label("Empty Trash", systemImage: "trash.slash")
                }
                .help("Permanently delete all items in trash")
                .disabled(deletedSnapshots.isEmpty)
            }
        }
        .task {
            await loadDeletedSnapshots()
        }
        .confirmationDialog("Empty Trash", isPresented: $showEmptyTrashConfirmation) {
            Button("Empty Trash", role: .destructive) {
                Task {
                    for snapshot in deletedSnapshots {
                        await viewModel.permanentlyDeleteTask(label: snapshot.taskLabel)
                    }
                    await loadDeletedSnapshots()
                    selectedSnapshot = nil
                    snapshotContent = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all items in the trash, including their execution history. This cannot be undone.")
        }
        .confirmationDialog("Permanently Delete", isPresented: $showPermanentDeleteConfirmation) {
            Button("Permanently Delete", role: .destructive) {
                if let snapshot = snapshotToPermanentlyDelete {
                    Task {
                        await viewModel.permanentlyDeleteTask(label: snapshot.taskLabel)
                        if selectedSnapshot?.taskLabel == snapshot.taskLabel {
                            selectedSnapshot = nil
                            snapshotContent = nil
                        }
                        await loadDeletedSnapshots()
                    }
                }
                snapshotToPermanentlyDelete = nil
            }
            Button("Cancel", role: .cancel) {
                snapshotToPermanentlyDelete = nil
            }
        } message: {
            Text("This will permanently delete \"\(snapshotToPermanentlyDelete?.taskName ?? "this task")\" and its execution history. This cannot be undone.")
        }
    }

    private var trashList: some View {
        List(deletedSnapshots, selection: $selectedSnapshot) { snapshot in
            TrashRow(snapshot: snapshot)
                .tag(snapshot)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSnapshot = snapshot
                    loadContent(for: snapshot)
                }
                .contextMenu {
                    Button("Restore") {
                        Task {
                            await viewModel.restoreDeletedTask(from: snapshot)
                            await loadDeletedSnapshots()
                        }
                    }
                    Divider()
                    Button("Permanently Delete", role: .destructive) {
                        snapshotToPermanentlyDelete = snapshot
                        showPermanentDeleteConfirmation = true
                    }
                }
        }
    }

    @ViewBuilder
    private var trashDetail: some View {
        if let snapshot = selectedSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.taskName)
                            .font(.headline)
                        HStack(spacing: 8) {
                            Text(snapshot.backend)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.2))
                                .cornerRadius(4)
                            Text("Deleted \(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(snapshot.taskLabel)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 8) {
                        Button("Restore") {
                            Task {
                                await viewModel.restoreDeletedTask(from: snapshot)
                                await loadDeletedSnapshots()
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Permanently Delete", role: .destructive) {
                            snapshotToPermanentlyDelete = snapshot
                            showPermanentDeleteConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                if let content = snapshotContent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Saved Configuration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

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
                    }
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
                Label("Select a Deleted Task", systemImage: "trash")
            } description: {
                Text("Select a deleted task to preview or restore it.")
            }
        }
    }

    private func loadDeletedSnapshots() async {
        deletedSnapshots = await TaskVersionService.shared.getDeletedSnapshots()
    }

    private func loadContent(for snapshot: TaskSnapshot) {
        Task {
            snapshotContent = await TaskVersionService.shared.readSnapshotContent(snapshot)
        }
    }
}

private struct TrashRow: View {
    let snapshot: TaskSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.taskName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            HStack(spacing: 6) {
                Text(snapshot.backend)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(3)

                Text(snapshot.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                + Text(" ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(snapshot.taskLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 4)
    }
}
