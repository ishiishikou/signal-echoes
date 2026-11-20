import Foundation

// iOS Simulator環境に依存しないSwiftモデルだけを使った合成Session V1。
@main struct EmitSyntheticSession {
    static func main() throws {
        let example = SessionV1(
            sessionId: "synthetic-swift-contract-test",
            durationMs: 1000,
            seed: 117,
            capture: CaptureInfo(completion: "complete"),
            observations: SessionObservations(
                ble: [BleBin(tMs: 1000, traceId: "e-synthetic-test",
                             rssiMedianDbm: -72.0, sampleCount: 2, lastSeenMs: 950)],
                selfSamples: [SelfSample(
                    tMs: 1000, segmentId: "segment-0", source: "coreLocation",
                    positionM: nil, horizontalAccuracyM: nil, ageMs: 1000,
                    quality: "unavailable", headingDeg: nil, headingAccuracyDeg: nil,
                    stepsDelta: nil, stepsIntervalMs: nil)],
                status: [
                    StatusEvent(tMs: 0, state: "recording", reason: "user_start",
                                scanActive: true, droppedCount: 0),
                    StatusEvent(tMs: 1000, state: "finished", reason: "user_stop",
                                scanActive: false, droppedCount: 0)
                ]))
        let encoded = try JSONEncoder().encode(example)
        FileHandle.standardOutput.write(encoded)
    }
}