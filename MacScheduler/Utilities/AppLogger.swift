//
//  AppLogger.swift
//  MacScheduler
//
//  Lightweight file-based logger with daily log rotation.
//  Writes to ~/Library/Logs/MacScheduler/MacScheduler-YYYY-MM-DD.log
//

import Foundation

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.macscheduler.logger", qos: .utility)
    private let dateFormatter: DateFormatter
    private let fileDateFormatter: DateFormatter

    /// Maximum size per log file before truncation (5 MB).
    private static let maxFileSize: UInt64 = 5_242_880

    private var logsDirectory: URL? {
        guard let libraryDir = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return nil
        }
        return libraryDir.appendingPathComponent("Logs/MacScheduler")
    }

    /// Resolved logs directory path for display in Settings.
    var logsDirectoryPath: String {
        logsDirectory?.path ?? "~/Library/Logs/MacScheduler"
    }

    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd"
        fileDateFormatter.locale = Locale(identifier: "en_US_POSIX")

        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        guard let dir = logsDirectory else { return }
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true,
                                         attributes: [.posixPermissions: 0o700])
    }

    private func logFileURL(for date: Date = Date()) -> URL? {
        guard let dir = logsDirectory else { return nil }
        let dateString = fileDateFormatter.string(from: date)
        return dir.appendingPathComponent("MacScheduler-\(dateString).log")
    }

    // MARK: - Public API

    func info(_ message: String, file: String = #file, function: String = #function) {
        log(level: "INFO", message: message, file: file, function: function)
    }

    func warn(_ message: String, file: String = #file, function: String = #function) {
        log(level: "WARN", message: message, file: file, function: function)
    }

    func error(_ message: String, file: String = #file, function: String = #function) {
        log(level: "ERROR", message: message, file: file, function: function)
    }

    func debug(_ message: String, file: String = #file, function: String = #function) {
        #if DEBUG
        log(level: "DEBUG", message: message, file: file, function: function)
        #endif
    }

    // MARK: - Log Retention

    /// Remove log files older than the given number of days. Pass 0 to keep forever.
    func pruneOldLogs(retentionDays: Int) {
        guard retentionDays > 0, let dir = logsDirectory else { return }
        queue.async { [fileManager] in
            let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
            guard let files = try? fileManager.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
            for file in files where file.pathExtension == "log" {
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modified = attrs.contentModificationDate,
                      modified < cutoff else { continue }
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - Private

    private func log(level: String, message: String, file: String, function: String) {
        let now = Date()
        let timestamp = dateFormatter.string(from: now)
        let source = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        let line = "[\(timestamp)] [\(level)] [\(source).\(function)] \(message)\n"

        queue.async { [self] in
            guard let fileURL = logFileURL(for: now) else { return }

            // Cap file size: if over limit, don't append
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? UInt64,
               size >= Self.maxFileSize {
                return
            }

            if fileManager.fileExists(atPath: fileURL.path) {
                guard let handle = FileHandle(forWritingAtPath: fileURL.path) else { return }
                handle.seekToEndOfFile()
                if let data = line.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            } else {
                // Create new log file with restricted permissions
                fileManager.createFile(atPath: fileURL.path,
                                       contents: line.data(using: .utf8),
                                       attributes: [.posixPermissions: 0o600])
            }
        }
    }
}
