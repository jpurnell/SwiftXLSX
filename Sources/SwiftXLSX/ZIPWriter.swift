import Foundation

enum ZIPWriter {

    static func write(entries: [(path: String, data: Data)], to url: URL) throws {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlsx_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }

        for entry in entries {
            let filePath = staging.appendingPathComponent(entry.path)
            let dir = filePath.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try entry.data.write(to: filePath)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", url.path] + entries.map(\.path)
        process.currentDirectoryURL = staging
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ZIPError.zipFailed(status: process.terminationStatus)
        }
    }

    enum ZIPError: Error {
        case zipFailed(status: Int32)
    }
}
