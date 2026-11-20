import Foundation

final class SessionExporter {
    static let shared = SessionExporter()
    private init() {}
    private var stagingDir: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("SignalEchoesExports", isDirectory: true)
    }

    func prepare(_ source: URL) throws -> URL {
        let dir = stagingDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        purge()
        let destination = dir.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: destination)
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete],
                                               ofItemAtPath: destination.path)
        return destination
    }

    func purge() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: stagingDir,
                 includingPropertiesForKeys: nil) else { return }
        for file in files { try? FileManager.default.removeItem(at: file) }
    }
}