import XCTest
@testable import SignalEchoes

final class RecorderTests: XCTestCase {
    func testBinBoundaries() {
        XCTAssertEqual(RecordingPolicy.binEnd(0), 1000)
        XCTAssertEqual(RecordingPolicy.binEnd(999), 1000)
        XCTAssertEqual(RecordingPolicy.binEnd(1000), 2000)
        XCTAssertEqual(RecordingPolicy.median([-80, -70]), -75)
        XCTAssertEqual(RecordingPolicy.median([-77, -90, -81]), -81)
    }
    func testLocationQuality() {
        XCTAssertEqual(RecordingPolicy.quality(accuracy: 20, ageMs: 5000), "usable")
        XCTAssertEqual(RecordingPolicy.quality(accuracy: 20.1, ageMs: 0), "coarse")
        XCTAssertEqual(RecordingPolicy.quality(accuracy: 50, ageMs: 0), "coarse")
        XCTAssertEqual(RecordingPolicy.quality(accuracy: 50.1, ageMs: 0), "unavailable")
        XCTAssertEqual(RecordingPolicy.quality(accuracy: 20, ageMs: 5001), "unavailable")
    }
    func testShortLivedIdentity() {
        let map = EphemeralIdentityMap(), id = UUID()
        let a = map.token(for: id, atMs: 0)
        XCTAssertEqual(map.token(for: id, atMs: 29_999), a)
        XCTAssertNotEqual(map.token(for: id, atMs: 59_999), a)
        let b = map.token(for: id, atMs: 60_000)
        map.reset()
        XCTAssertNotEqual(map.token(for: id, atMs: 60_000), b)
    }
    func testExplicitNulls() throws {
        let v = SelfSample(tMs: 1000, segmentId: "segment-0", source: "coreLocation",
          positionM: nil, horizontalAccuracyM: nil, ageMs: 900000, quality: "unavailable",
          headingDeg: nil, headingAccuracyDeg: nil, stepsDelta: nil, stepsIntervalMs: nil)
        let json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(v)) as! [String: Any]
        for k in ["positionM", "horizontalAccuracyM", "headingDeg", "headingAccuracyDeg",
                  "stepsDelta", "stepsIntervalMs", "floor"] {
            XCTAssertTrue(json[k] is NSNull, "missing: \(k)")
        }
    }
    func testSessionContract() throws {
        let v = SessionV1(sessionId: "test-synthetic", durationMs: 1000, seed: 1,
           capture: CaptureInfo(completion: "complete"),
           observations: SessionObservations(
             ble: [BleBin(tMs: 1000, traceId: "e-test", rssiMedianDbm: -75, sampleCount: 3, lastSeenMs: 990)],
             selfSamples: [SelfSample(tMs: 1000, segmentId: "segment-0", source: "coreLocation",
                positionM: nil, horizontalAccuracyM: nil, ageMs: 900000, quality: "unavailable",
                headingDeg: nil, headingAccuracyDeg: nil, stepsDelta: nil, stepsIntervalMs: nil)],
             status: [StatusEvent(tMs: 0, state: "recording", reason: "user_start",
                 scanActive: true, droppedCount: 0)]))
        let data = try JSONEncoder().encode(v)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertEqual(obj["schema"] as? String, "signal-echoes.session")
        XCTAssertEqual(obj["provenance"] as? String, "measured")
        XCTAssertEqual(obj["version"] as? Int, 1)
        let capture = try XCTUnwrap(obj["capture"] as? [String: Any])
        XCTAssertEqual(capture["mode"] as? String, "foreground")
        let obs = try XCTUnwrap(obj["observations"] as? [String: Any])
        XCTAssertNotNil(obs["self"])
        XCTAssertNil(obs["selfSamples"])
        let string = String(data: data, encoding: .utf8)!
        for forbidden in ["latitude", "longitude", "manufacturerData", "advertisementData",
                          "macAddress", "deviceName"] { XCTAssertFalse(string.contains(forbidden)) }
    }


    func testInterruptedWriterPreservesOneTerminalEvent() throws {
        let writer = SessionWriter.shared
        let id = "synthetic-test-" + UUID().uuidString
        try writer.begin(sessionId: id, seed: 42)
        try writer.add(StatusEvent(tMs: 0, state: "recording", reason: "user_start",
                                   scanActive: true, droppedCount: 0))
        try writer.add(StatusEvent(tMs: 1000, state: "interrupted", reason: "app_inactive",
                                   scanActive: false, droppedCount: 3))
        let url = try writer.finish(durationMs: 1000, completion: "interrupted")
        defer { try? writer.delete(url) }
        let data = try Data(contentsOf: url)
        let session = try JSONDecoder().decode(SessionV1.self, from: data)
        let terminal = session.observations.status.filter { $0.state == "interrupted" }
        XCTAssertEqual(terminal.count, 1)
        XCTAssertEqual(terminal.first?.reason, "app_inactive")
        XCTAssertEqual(terminal.first?.droppedCount, 3)
        XCTAssertEqual(session.capture.completion, "interrupted")
    }

    func testWriterRecoversMissingTerminalEvent() throws {
        let writer = SessionWriter.shared
        let id = "synthetic-test-" + UUID().uuidString
        try writer.begin(sessionId: id, seed: 43)
        try writer.add(StatusEvent(tMs: 0, state: "recording", reason: "user_start",
                                   scanActive: true, droppedCount: 0))
        let url = try writer.finish(durationMs: 1000, completion: "interrupted")
        defer { try? writer.delete(url) }
        let session = try JSONDecoder().decode(SessionV1.self, from: Data(contentsOf: url))
        let terminal = session.observations.status.filter { $0.state == "interrupted" }
        XCTAssertEqual(terminal.count, 1)
        XCTAssertEqual(terminal.first?.reason, "recovered_interruption")
    }
}