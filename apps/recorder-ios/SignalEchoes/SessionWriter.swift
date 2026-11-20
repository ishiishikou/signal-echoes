import Foundation

enum StorageError: LocalizedError {
    case limitExceeded, noJournal, invalidData
    var errorDescription: String? {
        switch self {
        case .limitExceeded: return "記録上限（15分・10万件・50MiB）に達しました。"
        case .noJournal: return "保存中の記録が見つかりません。"
        case .invalidData: return "保存データを回復できませんでした。"
        }
    }
}

final class SessionWriter {
    static let shared = SessionWriter()
    let directory: URL
    private var handle: FileHandle?
    private(set) var journalURL: URL?
    private(set) var recordCount = 0
    private(set) var byteCount = 0

    private init() {
        let home = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = home.appendingPathComponent("SignalEchoes", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? (directory as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
        purgeExpired()
    }

    private func protect(_ url: URL) {
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
        try? (url as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }

    func purgeExpired() {
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory,
              includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return }
        for url in entries where url != journalURL {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(date) > RecordingPolicy.retentionSeconds {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func begin(sessionId: String, seed: UInt32) throws {
        try close()
        recordCount = 0
        byteCount = 0
        let path = directory.appendingPathComponent(sessionId + ".ndjson")
        guard FileManager.default.createFile(atPath: path.path, contents: nil,
            attributes: [.protectionKey: FileProtectionType.complete]) else {
            throw StorageError.invalidData
        }
        journalURL = path
        handle = try FileHandle(forWritingTo: path)
        protect(path)
        try append(JournalRecord(kind: "header", header: JournalHeader(sessionId: sessionId, seed: seed)))
    }

    private func append(_ record: JournalRecord) throws {
        guard let handle else { throw StorageError.noJournal }
        var data = try JSONEncoder().encode(record)
        data.append(0x0A)
        let terminal = record.status?.state == "finished" || record.status?.state == "interrupted"
        let reserveBytes = terminal ? 0 : 4096
        let reserveRecords = terminal ? 0 : 1
        guard byteCount + data.count <= RecordingPolicy.maxFileBytes - reserveBytes,
              recordCount < RecordingPolicy.maxRecords - reserveRecords else {
            throw StorageError.limitExceeded
        }
        try handle.write(contentsOf: data)
        byteCount += data.count
        recordCount += 1
    }

    func add(_ bin: BleBin) throws {
        try append(JournalRecord(kind: "ble", ble: bin))
    }
    func add(_ sample: SelfSample) throws {
        try append(JournalRecord(kind: "self", selfSample: sample))
    }
    func add(_ event: StatusEvent) throws {
        try append(JournalRecord(kind: "status", status: event))
    }
    func flush() throws {
        guard let handle else { throw StorageError.noJournal }
        try handle.synchronize()
    }
    func close() throws {
        guard let handle else { return }
        defer { self.handle = nil }
        do {
            try handle.synchronize()
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }
    }

    /// プロセスが不意に終了した場合、改行完了済みの記録だけを復旧する。
    func recoverPending() {
        purgeExpired()
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory,
                includingPropertiesForKeys: nil) else { return }
        for url in entries where url.pathExtension == "ndjson" && url != journalURL {
            let finished = url.deletingPathExtension().appendingPathExtension("json")
            // atomicな完成済みJSONがある場合、古いジャーナルで上書きしない。
            if let bytes = try? Data(contentsOf: finished),
               let object = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
               object["schema"] as? String == "signal-echoes.session",
               object["version"] as? Int == 1 {
                try? FileManager.default.removeItem(at: url)
                continue
            }
            _ = try? finalize(url: url, durationMs: nil, completion: "interrupted")
        }
    }

    @discardableResult
    func finish(durationMs: Int, completion: String) throws -> URL {
        try close()
        guard let url = journalURL else { throw StorageError.noJournal }
        defer { journalURL = nil }
        return try finalize(url: url, durationMs: durationMs, completion: completion)
    }

    private func finalize(url: URL, durationMs: Int?, completion: String) throws -> URL {
        let data = try Data(contentsOf: url)
        guard data.count <= RecordingPolicy.maxFileBytes else { throw StorageError.limitExceeded }
        let decoder = JSONDecoder()
        let lines = data.split(separator: 0x0A, omittingEmptySubsequences: true)
        var header: JournalHeader?
        var observations = SessionObservations()
        var maxTime = 0
        for (index, line) in lines.enumerated() {
            // 末尾の不完全な行を無視。途中の不正行は復旧不能。
            do {
                let record = try decoder.decode(JournalRecord.self, from: Data(line))
                switch record.kind {
                case "header": header = record.header
                case "ble":
                    if let b = record.ble { observations.ble.append(b); maxTime = max(maxTime, b.tMs) }
                case "self":
                    if let s = record.selfSample { observations.selfSamples.append(s); maxTime = max(maxTime, s.tMs) }
                case "status":
                    if let e = record.status { observations.status.append(e); maxTime = max(maxTime, e.tMs) }
                default: break
                }
            } catch {
                guard index == lines.count - 1 && data.last != 0x0A else { throw StorageError.invalidData }
            }
        }
        guard let header else { throw StorageError.invalidData }
        let total = min(RecordingPolicy.maxDurationMs, max(durationMs ?? maxTime, maxTime))
        if completion == "interrupted" {
            // 通常の中断は既に終端イベントを持つ。復旧時だけ不足分を補う。
            if let lastEnd = observations.status.lastIndex(where: {
                $0.state == "finished" || $0.state == "interrupted"
            }), observations.status[lastEnd].state == "finished" {
                observations.status.remove(at: lastEnd)
            }
            if !observations.status.contains(where: { $0.state == "interrupted" }) {
                observations.status.append(StatusEvent(tMs: total, state: "interrupted",
                    reason: "recovered_interruption", scanActive: false, droppedCount: 0))
            }
        } else if !observations.status.contains(where: { $0.state == "finished" }) {
            throw StorageError.invalidData
        }
        // Session V1の時系列を正規化する。
        observations.ble.sort { $0.tMs < $1.tMs }
        observations.selfSamples.sort { $0.tMs < $1.tMs }
        observations.status.sort { $0.tMs < $1.tMs }
        let session = SessionV1(sessionId: header.sessionId, durationMs: total,
            seed: header.seed, capture: CaptureInfo(completion: completion),
            observations: observations)
        let encoded = try JSONEncoder().encode(session)
        guard encoded.count <= RecordingPolicy.maxFileBytes else { throw StorageError.limitExceeded }
        let temp = directory.appendingPathComponent(header.sessionId + ".tmp")
        let destination = directory.appendingPathComponent(header.sessionId + ".json")
        try encoded.write(to: temp, options: [.atomic, .completeFileProtection])
        protect(temp)
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temp, to: destination)
        protect(destination)
        try? FileManager.default.removeItem(at: url)
        return destination
    }

    func sessions() -> [URL] {
        purgeExpired()
        return ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    func delete(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL,
              url.pathExtension == "json" else { throw StorageError.invalidData }
        try FileManager.default.removeItem(at: url)
    }
}