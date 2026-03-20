import Foundation
#if os(iOS)
import UIKit
#endif

/// One row for a manual field test (distance, lighting, outcome). Persisted as JSON array in Application Support.
public struct VDTSessionTestEntry: Codable, Sendable, Identifiable {
    public var id: UUID
    public var date: Date
    public var deviceModel: String
    public var systemVersion: String
    public var distanceCm: Int?
    public var lightingNote: String
    public var outcomeNote: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        deviceModel: String,
        systemVersion: String,
        distanceCm: Int? = nil,
        lightingNote: String = "",
        outcomeNote: String
    ) {
        self.id = id
        self.date = date
        self.deviceModel = deviceModel
        self.systemVersion = systemVersion
        self.distanceCm = distanceCm
        self.lightingNote = lightingNote
        self.outcomeNote = outcomeNote
    }
}

public enum VDTSessionTestLog {
    private static let fileName = "vdt_session_test_log.json"

    private static func logURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("VisualDataTransfer", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    public static func loadEntries() throws -> [VDTSessionTestEntry] {
        let url = try logURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([VDTSessionTestEntry].self, from: data)
    }

    public static func append(_ entry: VDTSessionTestEntry) throws {
        var list = try loadEntries()
        list.append(entry)
        let data = try JSONEncoder().encode(list)
        try data.write(to: try logURL(), options: .atomic)
    }

    /// Device string suitable for matrix logging (best effort).
    public static var currentDeviceSummary: String {
        #if os(iOS)
        let m = UIDevice.current.model
        let name = UIDevice.current.name
        return "\(m) · \(name)"
        #elseif os(macOS)
        return ProcessInfo.processInfo.hostName
        #else
        return "unknown"
        #endif
    }

    public static var currentSystemVersion: String {
        #if os(iOS)
        return UIDevice.current.systemVersion
        #else
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    /// Writes a copy of the log to a temporary `.json` file for sharing.
    public static func exportTemporaryJSON() throws -> URL {
        let list = try loadEntries()
        let data = try JSONEncoder().encode(list)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("vdt_session_test_log_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: tmp, options: .atomic)
        return tmp
    }
}
