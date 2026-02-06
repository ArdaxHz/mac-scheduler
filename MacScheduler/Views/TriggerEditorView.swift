//
//  TriggerEditorView.swift
//  MacScheduler
//
//  View for configuring calendar-based triggers.
//

import SwiftUI

struct TriggerEditorView: View {
    @Binding var minute: Int
    @Binding var hour: Int
    @Binding var day: Int?
    @Binding var weekday: Int?
    @Binding var month: Int?

    @State private var scheduleType: ScheduleType = .daily

    enum ScheduleType: String, CaseIterable {
        case everyMinute = "Every Minute"
        case hourly = "Hourly"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"
        case custom = "Custom"
    }

    private let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let months = ["January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Schedule Type", selection: $scheduleType) {
                ForEach(ScheduleType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .onChange(of: scheduleType) { _, newValue in
                updateDefaults(for: newValue)
            }

            switch scheduleType {
            case .everyMinute:
                Text("Task will run every minute")
                    .font(.caption)
                    .foregroundColor(.secondary)

            case .hourly:
                HStack {
                    Text("At minute")
                    Picker("Minute", selection: $minute) {
                        ForEach(0..<60) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .frame(width: 80)
                    Text("of every hour")
                }

            case .daily:
                HStack {
                    Text("At")
                    Picker("Hour", selection: $hour) {
                        ForEach(0..<24) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .frame(width: 80)
                    Text(":")
                    Picker("Minute", selection: $minute) {
                        ForEach(0..<60) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .frame(width: 80)
                    Text("every day")
                }

            case .weekly:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("On")
                        Picker("Weekday", selection: Binding(
                            get: { weekday ?? 0 },
                            set: { weekday = $0 }
                        )) {
                            ForEach(0..<7) { d in
                                Text(weekdays[d]).tag(d)
                            }
                        }
                        .frame(width: 120)
                    }

                    HStack {
                        Text("At")
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 80)
                        Text(":")
                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 80)
                    }
                }

            case .monthly:
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("On day")
                        Picker("Day", selection: Binding(
                            get: { day ?? 1 },
                            set: { day = $0 }
                        )) {
                            ForEach(1...31, id: \.self) { d in
                                Text("\(d)").tag(d)
                            }
                        }
                        .frame(width: 80)
                        Text("of every month")
                    }

                    HStack {
                        Text("At")
                        Picker("Hour", selection: $hour) {
                            ForEach(0..<24) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .frame(width: 80)
                        Text(":")
                        Picker("Minute", selection: $minute) {
                            ForEach(0..<60) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .frame(width: 80)
                    }
                }

            case .custom:
                customScheduleView
            }

            previewText
        }
    }

    private var customScheduleView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Minute:")
                    .frame(width: 80, alignment: .leading)
                Picker("Minute", selection: $minute) {
                    ForEach(0..<60) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 80)
            }

            HStack {
                Text("Hour:")
                    .frame(width: 80, alignment: .leading)
                Picker("Hour", selection: $hour) {
                    ForEach(0..<24) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 80)
            }

            HStack {
                Text("Day:")
                    .frame(width: 80, alignment: .leading)
                Toggle("Specific day", isOn: Binding(
                    get: { day != nil },
                    set: { day = $0 ? 1 : nil }
                ))
                if day != nil {
                    Picker("Day", selection: Binding(
                        get: { day ?? 1 },
                        set: { day = $0 }
                    )) {
                        ForEach(1...31, id: \.self) { d in
                            Text("\(d)").tag(d)
                        }
                    }
                    .frame(width: 80)
                }
            }

            HStack {
                Text("Weekday:")
                    .frame(width: 80, alignment: .leading)
                Toggle("Specific weekday", isOn: Binding(
                    get: { weekday != nil },
                    set: { weekday = $0 ? 0 : nil }
                ))
                if weekday != nil {
                    Picker("Weekday", selection: Binding(
                        get: { weekday ?? 0 },
                        set: { weekday = $0 }
                    )) {
                        ForEach(0..<7) { d in
                            Text(weekdays[d]).tag(d)
                        }
                    }
                    .frame(width: 120)
                }
            }

            HStack {
                Text("Month:")
                    .frame(width: 80, alignment: .leading)
                Toggle("Specific month", isOn: Binding(
                    get: { month != nil },
                    set: { month = $0 ? 1 : nil }
                ))
                if month != nil {
                    Picker("Month", selection: Binding(
                        get: { month ?? 1 },
                        set: { month = $0 }
                    )) {
                        ForEach(1...12, id: \.self) { m in
                            Text(months[m - 1]).tag(m)
                        }
                    }
                    .frame(width: 120)
                }
            }
        }
    }

    private var previewText: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            Text(schedulePreview)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    private var schedulePreview: String {
        let schedule = CalendarSchedule(
            minute: minute,
            hour: hour,
            day: day,
            weekday: weekday,
            month: month
        )
        return schedule.displayString
    }

    private func updateDefaults(for type: ScheduleType) {
        switch type {
        case .everyMinute:
            day = nil
            weekday = nil
            month = nil
        case .hourly:
            minute = 0
            day = nil
            weekday = nil
            month = nil
        case .daily:
            day = nil
            weekday = nil
            month = nil
        case .weekly:
            weekday = weekday ?? 1
            day = nil
            month = nil
        case .monthly:
            day = day ?? 1
            weekday = nil
            month = nil
        case .custom:
            break
        }
    }
}

#Preview {
    Form {
        TriggerEditorView(
            minute: .constant(0),
            hour: .constant(9),
            day: .constant(nil),
            weekday: .constant(nil),
            month: .constant(nil)
        )
    }
    .formStyle(.grouped)
}
