import SwiftUI
import Foundation

@MainActor
final class SessionController: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var durationSeconds = 0
    @Published private(set) var receivedSamples = 0
    @Published private(set) var visibleSignals = 0
    @Published private(set) var positionLabel = "未測位"
    @Published private(set) var bluetoothLabel = "待機中"
    @Published private(set) var statusLabel = "記録を開始できます"
    @Published private(set) var recentSessions: [URL] = []
    @Published var errorText: String?
    @Published var shareURL: URL?

    private let scanner = BLEScanner()
    private let location = LocationRecorder()
    private let motion = MotionRecorder()
    private let writer = SessionWriter.shared
    private var timer: Timer?
    private var startUptime = 0.0
    private var pending: [Int: [String: [Double]]] = [:]
    private var lastSeenByBin: [Int: [String: Int]] = [:]
    private var nextBoundary = 1000
    private var lastStatusAt = 0
    private var storedBins = 0

    init() {
        writer.recoverPending()
        refreshFiles()
    }
    private func elapsedMs() -> Int {
        min(RecordingPolicy.maxDurationMs,
            max(0, Int((ProcessInfo.processInfo.systemUptime - startUptime) * 1000)))
    }
    func refreshFiles() { recentSessions = writer.sessions() }

    func start() {
        guard !isRecording else { return }
        SessionExporter.shared.purge()
        shareURL = nil
        errorText = nil
        startUptime = ProcessInfo.processInfo.systemUptime
        durationSeconds = 0
        receivedSamples = 0
        visibleSignals = 0
        storedBins = 0
        pending.removeAll()
        lastSeenByBin.removeAll()
        nextBoundary = 1000
        lastStatusAt = 0
        positionLabel = "測位中"
        bluetoothLabel = "確認中"
        do {
            try writer.begin(sessionId: UUID().uuidString.lowercased(), seed: UInt32.random(in: 1...UInt32.max))
            try writer.add(StatusEvent(tMs: 0, state: "recording", reason: "user_start",
                                        scanActive: false, droppedCount: 0))
        } catch {
            errorText = error.localizedDescription
            return
        }
        isRecording = true
        location.start { [weak self] state in
            guard let self, self.isRecording else { return }
            if state == "location_unavailable" { self.positionLabel = "位置情報を利用できません" }
        }
        motion.start()
        scanner.onObservation = { [weak self] observation in
            self?.receive(observation)
        }
        scanner.onState = { [weak self] state in
            guard let self, self.isRecording else { return }
            self.bluetoothLabel = state == "scanning" ? "受信中" :
                 state == "permission_denied" ? "Bluetooth許可がありません" : "Bluetooth停止・未利用"
            if state == "bluetooth_off" || state == "permission_denied" {
                self.writeStatus(state: "degraded", reason: state)
            }
        }
        scanner.start { [weak self] in self?.elapsedMs() ?? 0 }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        statusLabel = "前景で記録中。画面を離れると自動停止します。"
    }

    private func receive(_ sample: BLEObservation) {
        guard isRecording, sample.tMs >= 0, sample.tMs < RecordingPolicy.maxDurationMs else { return }
        let end = RecordingPolicy.binEnd(sample.tMs)
        // 遅延配送で既に閉じたビンへデータを混入しない。
        guard end >= nextBoundary else { return }
        pending[end, default: [:]][sample.traceId, default: []].append(sample.rssi)
        lastSeenByBin[end, default: [:]][sample.traceId] = sample.tMs
        receivedSamples += 1
        visibleSignals = pending[end]?.count ?? 0
        if pending.values.reduce(0, { $0 + $1.values.reduce(0, { $0 + $1.count }) }) > 20_000 {
            terminate(interrupted: true, reason: "overflow")
        }
    }

    private func writeStatus(state: String, reason: String) {
        guard isRecording else { return }
        do {
            try writer.add(StatusEvent(tMs: elapsedMs(), state: state,
                reason: reason, scanActive: scanner.isScanning, droppedCount: 0))
        } catch {
            terminate(interrupted: true, reason: "write_failed")
        }
    }

    private func flushBoundary(_ end: Int) throws {
        let perTrace = pending.removeValue(forKey: end) ?? [:]
        let lastTimes = lastSeenByBin.removeValue(forKey: end) ?? [:]
        for (traceId, values) in perTrace.sorted(by: { $0.key < $1.key }) {
            guard let last = lastTimes[traceId], !values.isEmpty else { continue }
            try writer.add(BleBin(tMs: end, traceId: traceId, rssiMedianDbm: RecordingPolicy.median(values),
                                  sampleCount: values.count, lastSeenMs: last))
            storedBins += 1
        }
        scanner.prune(atMs: end)
        let steps = motion.sample(atMs: end)
        let sample = location.sample(atMs: end, stepsDelta: steps.stepsDelta, stepsIntervalMs: steps.intervalMs)
        positionLabel = sample.quality == "usable" ? "位置記録中" :
                       sample.quality == "coarse" ? "位置精度が低い" : "位置情報なし"
        try writer.add(sample)
    }

    private func tick() {
        guard isRecording else { return }
        let elapsed = elapsedMs()
        durationSeconds = elapsed / 1000
        do {
            while nextBoundary <= elapsed {
                try flushBoundary(nextBoundary)
                nextBoundary += 1000
            }
            if elapsed - lastStatusAt >= 5000 {
                lastStatusAt = elapsed
                try writer.add(StatusEvent(tMs: elapsed, state: "recording",
                   reason: "heartbeat", scanActive: scanner.isScanning, droppedCount: 0))
                writer.flush()
            }
        } catch {
            errorText = error.localizedDescription
            terminate(interrupted: true, reason: error is StorageError ? "storage_limit" : "write_failed")
            return
        }
        if elapsed >= RecordingPolicy.maxDurationMs {
            terminate(interrupted: false, reason: "user_stop")
        }
    }

    func stop() {
        guard isRecording else { return }
        terminate(interrupted: false, reason: "user_stop")
    }
    func handleAppInactive() {
        if isRecording {
            terminate(interrupted: true, reason: "app_inactive")
        }
    }

    private func terminate(interrupted: Bool, reason: String) {
        guard isRecording else { return }
        let end = elapsedMs()
        timer?.invalidate()
        timer = nil
        // 残っている完全な1秒ビンのみを確定する。
        do {
            while nextBoundary <= end {
                try flushBoundary(nextBoundary)
                nextBoundary += 1000
            }
            try writer.add(StatusEvent(tMs: end, state: interrupted ? "interrupted" : "finished",
                reason: reason, scanActive: false, droppedCount: 0))
        } catch {
            errorText = error.localizedDescription
        }
        scanner.stop()
        motion.stop()
        location.stop()
        isRecording = false
        pending.removeAll()
        lastSeenByBin.removeAll()
        do {
            _ = try writer.finish(durationMs: end, completion: interrupted ? "interrupted" : "complete")
            statusLabel = interrupted ? "記録は中断され、可能な範囲で保存しました。" : "記録を保存しました。"
        } catch {
            errorText = "記録の保存に失敗しました: " + error.localizedDescription
            statusLabel = "保存失敗。再起動後の復旧を試してください。"
        }
        refreshFiles()
    }

    func prepareShare(_ url: URL) {
        do { shareURL = try SessionExporter.shared.prepare(url) }
        catch { errorText = error.localizedDescription }
    }
    func delete(_ url: URL) {
        do {
            try writer.delete(url)
            shareURL = nil
            refreshFiles()
        } catch { errorText = error.localizedDescription }
    }
}