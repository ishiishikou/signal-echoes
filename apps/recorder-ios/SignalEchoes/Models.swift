import Foundation

struct BleBin: Codable, Equatable {
    let tMs: Int
    let traceId: String
    let rssiMedianDbm: Double
    let sampleCount: Int
    let lastSeenMs: Int
}
struct SelfSample: Codable {
    let tMs: Int
    let segmentId: String
    let source: String
    let positionM: [Double]?
    let horizontalAccuracyM: Double?
    let ageMs: Int
    let quality: String
    let headingDeg: Double?
    let headingAccuracyDeg: Double?
    let stepsDelta: Int?
    let stepsIntervalMs: Int?
    let floor: Int? = nil

    // Zod の厳密なスキーマは、欠測時も必須キーを null で要求する。
    enum CodingKeys: String, CodingKey {
        case tMs, segmentId, source, positionM, horizontalAccuracyM, ageMs, quality
        case headingDeg, headingAccuracyDeg, stepsDelta, stepsIntervalMs, floor
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(tMs, forKey: .tMs)
        try c.encode(segmentId, forKey: .segmentId)
        try c.encode(source, forKey: .source)
        if let positionM { try c.encode(positionM, forKey: .positionM) }
        else { try c.encodeNil(forKey: .positionM) }
        if let horizontalAccuracyM { try c.encode(horizontalAccuracyM, forKey: .horizontalAccuracyM) }
        else { try c.encodeNil(forKey: .horizontalAccuracyM) }
        try c.encode(ageMs, forKey: .ageMs)
        try c.encode(quality, forKey: .quality)
        if let headingDeg { try c.encode(headingDeg, forKey: .headingDeg) }
        else { try c.encodeNil(forKey: .headingDeg) }
        if let headingAccuracyDeg { try c.encode(headingAccuracyDeg, forKey: .headingAccuracyDeg) }
        else { try c.encodeNil(forKey: .headingAccuracyDeg) }
        if let stepsDelta { try c.encode(stepsDelta, forKey: .stepsDelta) }
        else { try c.encodeNil(forKey: .stepsDelta) }
        if let stepsIntervalMs { try c.encode(stepsIntervalMs, forKey: .stepsIntervalMs) }
        else { try c.encodeNil(forKey: .stepsIntervalMs) }
        try c.encodeNil(forKey: .floor)
    }
}
struct StatusEvent: Codable {
    let tMs: Int
    let state: String
    let reason: String
    let scanActive: Bool
    let droppedCount: Int
}
struct CaptureInfo: Codable {
    let mode = "foreground"
    let serviceFilter = "none"
    let binMs = 1000
    let completion: String
}
struct SessionObservations: Codable {
    var ble: [BleBin] = []
    var selfSamples: [SelfSample] = []
    var status: [StatusEvent] = []
    enum CodingKeys: String, CodingKey {
        case ble, status
        case selfSamples = "self"
    }
}
struct SessionV1: Codable {
    let schema = "signal-echoes.session"
    let version = 1
    let provenance = "measured"
    let sessionId: String
    let durationMs: Int
    let coordinateFrame = "local-east-up-south-m"
    let seed: UInt32
    let capture: CaptureInfo
    let observations: SessionObservations
}
struct JournalHeader: Codable {
    let sessionId: String
    let seed: UInt32
}
struct JournalRecord: Codable {
    let kind: String
    var header: JournalHeader? = nil
    var ble: BleBin? = nil
    var selfSample: SelfSample? = nil
    var status: StatusEvent? = nil
    enum CodingKeys: String, CodingKey {
        case kind, header, ble, status
        case selfSample = "self"
    }
}
enum RecordingPolicy {
    static let maxDurationMs = 900_000
    static let maxRecords = 100_000
    static let maxFileBytes = 50 * 1024 * 1024
    static let tokenLifetimeMs = 120_000
    static let tokenSilenceMs = 30_000
    static let retentionSeconds: TimeInterval = 24 * 60 * 60
    static func binEnd(_ tMs: Int) -> Int {
        (tMs / 1000 + 1) * 1000
    }
    static func quality(accuracy: Double, ageMs: Int) -> String {
        if !accuracy.isFinite || accuracy < 0 || ageMs > 5000 { return "unavailable" }
        if accuracy <= 20 { return "usable" }
        if accuracy <= 50 { return "coarse" }
        return "unavailable"
    }
    static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return -127 }
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}