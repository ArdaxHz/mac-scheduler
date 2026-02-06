//
//  TaskListView.swift
//  MacScheduler
//
//  List view showing all scheduled tasks.
//

import SwiftUI

struct TaskListView: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    var onEdit: (ScheduledTask) -> Void
    var onSelect: (ScheduledTask) -> Void

    @State private var sortOrder = [KeyPathComparator(\ScheduledTask.name)]

    var body: some View {
        VStack(spacing: 0) {
            filterBar

            if viewModel.filteredTasks.isEmpty {
                emptyState
            } else {
                taskTable
            }
        }
        .navigationTitle("Scheduled Tasks")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await viewModel.discoverExistingTasks() }
                } label: {
                    Label("Discover Tasks", systemImage: "arrow.clockwise")
                }
                .help("Discover existing launchd and cron tasks")

                Menu {
                    Button("All") { viewModel.filterBackend = nil }
                    Divider()
                    ForEach(SchedulerBackend.allCases, id: \.self) { backend in
                        Button(backend.displayName) {
                            viewModel.filterBackend = backend
                        }
                    }
                } label: {
                    Label("Filter Backend", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private var filterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tasks...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)

                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)

            Spacer()

            Picker("Status", selection: $viewModel.filterState) {
                Text("All").tag(TaskState?.none)
                Divider()
                ForEach(TaskState.allCases, id: \.self) { state in
                    Text(state.rawValue).tag(TaskState?.some(state))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 120)
        }
        .padding()
    }

    private var taskTable: some View {
        Table(viewModel.filteredTasks, selection: $viewModel.selectedTask.id, sortOrder: $sortOrder) {
            TableColumn("") { task in
                Image(systemName: task.status.state.systemImage)
                    .foregroundColor(statusColor(for: task.status.state))
            }
            .width(20)

            TableColumn("Name", value: \.name) { task in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(task.name)
                            .fontWeight(.medium)
                        if task.isExternal {
                            Text("External")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
                    }
                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if task.isExternal, let label = task.externalLabel {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Trigger") { task in
                HStack {
                    Image(systemName: task.trigger.type.systemImage)
                        .foregroundColor(.secondary)
                    Text(task.trigger.displayString)
                        .lineLimit(1)
                }
            }
            .width(min: 120, ideal: 180)

            TableColumn("Backend") { task in
                Text(task.backend.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(task.backend == .launchd ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(4)
            }
            .width(70)

            TableColumn("Last Run") { task in
                if let lastRun = task.status.lastRun {
                    Text(lastRun, style: .relative)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never")
                        .foregroundColor(.secondary)
                }
            }
            .width(100)
        }
        .contextMenu(forSelectionType: ScheduledTask.ID.self) { ids in
            if let id = ids.first, let task = viewModel.tasks.first(where: { $0.id == id }) {
                contextMenuItems(for: task)
            }
        } primaryAction: { ids in
            if let id = ids.first, let task = viewModel.tasks.first(where: { $0.id == id }) {
                onSelect(task)
            }
        }
        .onChange(of: sortOrder) { _, newOrder in
            viewModel.tasks.sort(using: newOrder)
        }
    }

    @ViewBuilder
    private func contextMenuItems(for task: ScheduledTask) -> some View {
        Button {
            Task { await viewModel.runTaskNow(task) }
        } label: {
            Label("Run Now", systemImage: "play.fill")
        }

        Divider()

        Button {
            Task { await viewModel.toggleTaskEnabled(task) }
        } label: {
            if task.isEnabled {
                Label("Disable", systemImage: "pause.fill")
            } else {
                Label("Enable", systemImage: "checkmark")
            }
        }

        Button {
            onEdit(task)
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Divider()

        Button(role: .destructive) {
            Task { await viewModel.deleteTask(task) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Tasks", systemImage: "calendar.badge.exclamationmark")
        } description: {
            if !viewModel.searchText.isEmpty {
                Text("No tasks match your search")
            } else if viewModel.filterBackend != nil || viewModel.filterState != nil {
                Text("No tasks match the selected filters")
            } else {
                Text("Create a new task to get started")
            }
        } actions: {
            if viewModel.searchText.isEmpty && viewModel.filterBackend == nil && viewModel.filterState == nil {
                Button("Create Task") {
                    NotificationCenter.default.post(name: .createNewTask, object: nil)
                }
            }
        }
    }

    private func statusColor(for state: TaskState) -> Color {
        switch state {
        case .enabled: return .green
        case .disabled: return .secondary
        case .running: return .blue
        case .error: return .red
        }
    }
}

private extension Binding where Value == ScheduledTask? {
    var id: Binding<UUID?> {
        Binding<UUID?>(
            get: { self.wrappedValue?.id },
            set: { _ in }
        )
    }
}

#Preview {
    TaskListView(onEdit: { _ in }, onSelect: { _ in })
        .environmentObject(TaskListViewModel())
}
