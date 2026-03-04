//
//  VMInfo.swift
//  MacScheduler
//
//  VM metadata model for virtual machine backends.
//

import Foundation

struct VMInfo: Codable, Equatable {
    var vmId: String           // UUID or unique identifier from the hypervisor
    var vmName: String
    var vmState: String        // "running", "stopped", "paused", "suspended", etc.
    var backend: SchedulerBackend
    var osType: String?
    var cpuCount: Int?
    var memoryMB: Int?
}
