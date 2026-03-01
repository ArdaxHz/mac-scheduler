//
//  TaskSnapshot.swift
//  MacScheduler
//
//  Data model for task version history snapshots.
//

import Foundation

struct TaskSnapshot: Codable, Identifiable {
    let id: UUID
    let taskLabel: String
    let taskName: String
    let timestamp: Date
    let reason: SnapshotReason
    let backend: String
    let snapshotFileName: String
    let newLabel: String?

    enum SnapshotReason: String, Codable {
        case beforeEdit
        case beforeDelete
    }

    init(taskLabel: String, taskName: String, reason: SnapshotReason, backend: String, snapshotFileName: String, newLabel: String? = nil) {
        self.id = UUID()
        self.taskLabel = taskLabel
        self.taskName = taskName
        self.timestamp = Date()
        self.reason = reason
        self.backend = backend
        self.snapshotFileName = snapshotFileName
        self.newLabel = newLabel
    }
}
