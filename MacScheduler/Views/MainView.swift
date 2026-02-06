//
//  MainView.swift
//  MacScheduler
//
//  Main window with sidebar navigation.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: TaskListViewModel
    @State private var showingEditor = false
    @State private var editingTask: ScheduledTask?
    @State private var selectedNavItem: NavigationItem = .allTasks

    enum NavigationItem: Hashable {
        case allTasks
        case history
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            contentView
        } detail: {
            detailView
        }
        .sheet(isPresented: $showingEditor) {
            TaskEditorView(task: editingTask) { task in
                if editingTask != nil {
                    Task { await viewModel.updateTask(task) }
                } else {
                    Task { await viewModel.addTask(task) }
                }
            }
            .id(editingTask?.id ?? UUID())
        }
        .onReceive(NotificationCenter.default.publisher(for: .createNewTask)) { _ in
            editingTask = nil
            showingEditor = true
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    private var sidebar: some View {
        List(selection: $selectedNavItem) {
            Section("Tasks") {
                NavigationLink(value: NavigationItem.allTasks) {
                    Label("All Tasks", systemImage: "list.bullet")
                }
                .badge(viewModel.tasks.count)
            }

            Section("Activity") {
                NavigationLink(value: NavigationItem.history) {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section("Status") {
                HStack {
                    Label("Enabled", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Text("\(viewModel.enabledTaskCount)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Disabled", systemImage: "pause.circle.fill")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(viewModel.disabledTaskCount)")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 250)
        .toolbar {
            ToolbarItem {
                Button {
                    editingTask = nil
                    showingEditor = true
                } label: {
                    Label("Add Task", systemImage: "plus")
                }
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch selectedNavItem {
        case .allTasks:
            TaskListView(
                onEdit: { task in
                    editingTask = task
                    showingEditor = true
                },
                onSelect: { task in
                    viewModel.selectedTask = task
                }
            )
        case .history:
            HistoryView()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        if let task = viewModel.selectedTask {
            TaskDetailView(task: task) { task in
                editingTask = task
                showingEditor = true
            }
        } else {
            ContentUnavailableView {
                Label("No Task Selected", systemImage: "calendar.badge.clock")
            } description: {
                Text("Select a task from the list to view its details")
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(TaskListViewModel())
}
