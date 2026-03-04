//
//  CronParser.swift
//  MacScheduler
//
//  Utility for parsing and generating cron expressions.
//

import Foundation

struct CronExpression: Equatable {
    var minute: String
    var hour: String
    var dayOfMonth: String
    var month: String
    var dayOfWeek: String

    init(minute: String = "*",
         hour: String = "*",
         dayOfMonth: String = "*",
         month: String = "*",
         dayOfWeek: String = "*") {
        self.minute = minute
        self.hour = hour
        self.dayOfMonth = dayOfMonth
        self.month = month
        self.dayOfWeek = dayOfWeek
    }

    var expression: String {
        "\(minute) \(hour) \(dayOfMonth) \(month) \(dayOfWeek)"
    }

    var displayString: String {
        var parts: [String] = []

        if minute != "*" && hour != "*" {
            parts.append("At \(hour.padding(toLength: 2, withPad: "0", startingAt: 0)):\(minute.padding(toLength: 2, withPad: "0", startingAt: 0))")
        } else if hour != "*" {
            parts.append("At hour \(hour)")
        } else if minute != "*" {
            parts.append("At minute \(minute)")
        } else {
            parts.append("Every minute")
        }

        if dayOfMonth != "*" {
            parts.append("on day \(dayOfMonth)")
        }

        if month != "*" {
            let months = ["", "January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
            if let m = Int(month), m >= 1 && m <= 12 {
                parts.append("of \(months[m])")
            } else {
                parts.append("in month \(month)")
            }
        }

        if dayOfWeek != "*" {
            let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            if let d = Int(dayOfWeek), d >= 0 && d <= 6 {
                parts.append("on \(weekdays[d])")
            } else {
                parts.append("on weekday \(dayOfWeek)")
            }
        }

        return parts.joined(separator: " ")
    }
}

class CronParser {

    static func parse(_ expression: String) -> CronExpression? {
        let components = expression.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        guard components.count == 5 else {
            return nil
        }

        return CronExpression(
            minute: components[0],
            hour: components[1],
            dayOfMonth: components[2],
            month: components[3],
            dayOfWeek: components[4]
        )
    }

    static func fromCalendarSchedule(_ schedule: CalendarSchedule) -> CronExpression {
        CronExpression(
            minute: schedule.minute.map { String($0) } ?? "*",
            hour: schedule.hour.map { String($0) } ?? "*",
            dayOfMonth: schedule.day.map { String($0) } ?? "*",
            month: schedule.month.map { String($0) } ?? "*",
            dayOfWeek: schedule.weekday.map { String($0) } ?? "*"
        )
    }

    static func toCalendarSchedule(_ cron: CronExpression) -> CalendarSchedule {
        CalendarSchedule(
            minute: Int(cron.minute),
            hour: Int(cron.hour),
            day: Int(cron.dayOfMonth),
            weekday: Int(cron.dayOfWeek),
            month: Int(cron.month)
        )
    }

    static func validate(_ expression: String) -> [String] {
        var errors: [String] = []

        guard let cron = parse(expression) else {
            errors.append("Invalid cron expression format. Expected 5 fields: minute hour day month weekday")
            return errors
        }

        if !isValidField(cron.minute, min: 0, max: 59) {
            errors.append("Invalid minute field: \(cron.minute) (must be 0-59 or *)")
        }

        if !isValidField(cron.hour, min: 0, max: 23) {
            errors.append("Invalid hour field: \(cron.hour) (must be 0-23 or *)")
        }

        if !isValidField(cron.dayOfMonth, min: 1, max: 31) {
            errors.append("Invalid day of month field: \(cron.dayOfMonth) (must be 1-31 or *)")
        }

        if !isValidField(cron.month, min: 1, max: 12) {
            errors.append("Invalid month field: \(cron.month) (must be 1-12 or *)")
        }

        if !isValidField(cron.dayOfWeek, min: 0, max: 6) {
            errors.append("Invalid day of week field: \(cron.dayOfWeek) (must be 0-6 or *)")
        }

        return errors
    }

    private static func isValidField(_ field: String, min: Int, max: Int) -> Bool {
        if field == "*" {
            return true
        }

        if field.contains("/") {
            let parts = field.components(separatedBy: "/")
            guard parts.count == 2,
                  let step = Int(parts[1]),
                  step > 0 else {
                return false
            }
            return parts[0] == "*" || isValidField(parts[0], min: min, max: max)
        }

        if field.contains("-") {
            let parts = field.components(separatedBy: "-")
            guard parts.count == 2,
                  let start = Int(parts[0]),
                  let end = Int(parts[1]),
                  start >= min, start <= max,
                  end >= min, end <= max,
                  start <= end else {
                return false
            }
            return true
        }

        if field.contains(",") {
            let values = field.components(separatedBy: ",")
            return values.allSatisfy { isValidField($0, min: min, max: max) }
        }

        guard let value = Int(field) else {
            return false
        }

        return value >= min && value <= max
    }
}
