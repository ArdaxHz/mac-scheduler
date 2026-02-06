//
//  TaskEditorView.swift
//  MacScheduler
//
//  Form for creating and editing tasks.
//

import SwiftUI

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var editorViewModel = TaskEditorViewModel()

    let task: ScheduledTask?
    let onSave: (ScheduledTask) -> Void

    @State private var showFilePicker = false
    @State private var filePickerField: FilePickerField = .executable

    enum FilePickerField {
        case executable
        case workingDirectory
        case standardOut
        case standardError
    }

    init(task: ScheduledTask? = nil, onSave: @escaping (ScheduledTask) -> Void) {
        self.task = task
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                actionSection
                triggerSection
                optionsSection
            }
            .formStyle(.grouped)
            .navigationTitle(editorViewModel.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(editorViewModel.name.isEmpty)
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
            .onChange(of: task?.id) { _, newId in
                if let task = task {
                    editorViewModel.loadTask(task)
                } else {
                    editorViewModel.reset()
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                handleFilePicker(result)
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }

    private var basicInfoSection: some View {
        Section("Basic Information") {
            TextField("Task Name", text: $editorViewModel.name)

            TextField("Description", text: $editorViewModel.taskDescription, axis: .vertical)
                .lineLimit(2...4)

            Picker("Backend", selection: $editorViewModel.backend) {
                ForEach(SchedulerBackend.allCases, id: \.self) { backend in
                    Text(backend.displayName).tag(backend)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var actionSection: some View {
        Section("Action") {
            Picker("Action Type", selection: $editorViewModel.actionType) {
                ForEach(TaskActionType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.systemImage).tag(type)
                }
            }

            switch editorViewModel.actionType {
            case .executable:
                executableFields
            case .shellScript:
                shellScriptFields
            case .appleScript:
                appleScriptFields
            }

            HStack {
                TextField("Working Directory (optional)", text: $editorViewModel.workingDirectory)
                Button {
                    filePickerField = .workingDirectory
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }
        }
    }

    private var executableFields: some View {
        Group {
            HStack {
                TextField("Executable Path", text: $editorViewModel.executablePath)
                Button {
                    filePickerField = .executable
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }

            TextField("Arguments (space-separated)", text: $editorViewModel.arguments)
        }
    }

    private var shellScriptFields: some View {
        Group {
            HStack {
                TextField("Script Path (optional)", text: $editorViewModel.executablePath)
                Button {
                    filePickerField = .executable
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }

            VStack(alignment: .leading) {
                Text("Script Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editorViewModel.scriptContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            }
        }
    }

    private var appleScriptFields: some View {
        Group {
            HStack {
                TextField("Script Path (optional)", text: $editorViewModel.executablePath)
                Button {
                    filePickerField = .executable
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }

            VStack(alignment: .leading) {
                Text("AppleScript Content")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $editorViewModel.scriptContent)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 100)
                    .border(Color.secondary.opacity(0.3))
            }
        }
    }

    private var triggerSection: some View {
        Section("Trigger") {
            Picker("Trigger Type", selection: $editorViewModel.triggerType) {
                ForEach(TriggerType.allCases, id: \.self) { type in
                    HStack {
                        Label(type.rawValue, systemImage: type.systemImage)
                        if editorViewModel.backend == .cron && !type.supportsCron {
                            Text("(Not supported by cron)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(type)
                }
            }

            switch editorViewModel.triggerType {
            case .calendar:
                TriggerEditorView(
                    minute: $editorViewModel.scheduleMinute,
                    hour: $editorViewModel.scheduleHour,
                    day: $editorViewModel.scheduleDay,
                    weekday: $editorViewModel.scheduleWeekday,
                    month: $editorViewModel.scheduleMonth
                )
            case .interval:
                intervalFields
            case .atLogin, .atStartup, .onDemand:
                Text(editorViewModel.triggerType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var intervalFields: some View {
        HStack {
            TextField("Interval", value: $editorViewModel.intervalValue, format: .number)
                .frame(width: 80)

            Picker("Unit", selection: $editorViewModel.intervalUnit) {
                ForEach(TaskEditorViewModel.IntervalUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
            }
            .frame(width: 120)

            Text("(\(editorViewModel.intervalValue * editorViewModel.intervalUnit.multiplier) seconds)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Run at Load", isOn: $editorViewModel.runAtLoad)
                .help("Run the task when it is loaded (enabled)")

            Toggle("Keep Alive", isOn: $editorViewModel.keepAlive)
                .help("Restart the task if it exits")
                .disabled(editorViewModel.backend == .cron)

            HStack {
                TextField("Standard Output Path (optional)", text: $editorViewModel.standardOutPath)
                Button {
                    filePickerField = .standardOut
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }

            HStack {
                TextField("Standard Error Path (optional)", text: $editorViewModel.standardErrorPath)
                Button {
                    filePickerField = .standardError
                    showFilePicker = true
                } label: {
                    Image(systemName: "folder")
                }
            }
        }
    }

    private func save() {
        guard editorViewModel.validate() else { return }

        let task = editorViewModel.buildTask()
        onSave(task)
        dismiss()
    }

    private func handleFilePicker(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let path = url.path
        switch filePickerField {
        case .executable:
            editorViewModel.executablePath = path
        case .workingDirectory:
            editorViewModel.workingDirectory = path
        case .standardOut:
            editorViewModel.standardOutPath = path
        case .standardError:
            editorViewModel.standardErrorPath = path
        }
    }
}

#Preview {
    TaskEditorView(onSave: { _ in })
}
