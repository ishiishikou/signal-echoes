import Foundation
import CoreBluetooth

struct BLEObservation {
    let traceId: String
    let tMs: Int
    let rssi: Double
}

/// foreground専用。接続・サービス照会・広告payloadの永続化は行わない。
final class BLEScanner: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private let identities = EphemeralIdentityMap()
    private var shouldScan = false
    private var clockMs: (() -> Int)?
    var onObservation: ((BLEObservation) -> Void)?
    var onState: ((String) -> Void)?
    private(set) var isScanning = false

    func start(clockMs: @escaping () -> Int) {
        stop()
        self.clockMs = clockMs
        shouldScan = true
        manager = CBCentralManager(delegate: self, queue: .main)
        if manager?.state == .poweredOn { beginScan() }
    }

    private func beginScan() {
        guard shouldScan, let manager = manager, manager.state == .poweredOn else { return }
        // allowDuplicatesは前景でもOSが希望通りに配送する保証ではない。
        manager.scanForPeripherals(withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = manager.isScanning
        onState?(isScanning ? "scanning" : "scan_unavailable")
    }

    func prune(atMs: Int) { identities.prune(atMs: atMs) }
    func stop() {
        shouldScan = false
        manager?.stopScan()
        manager?.delegate = nil
        manager = nil
        identities.reset()
        isScanning = false
        clockMs = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: beginScan()
        case .poweredOff:
            isScanning = false
            onState?("bluetooth_off")
        case .unauthorized:
            isScanning = false
            onState?("permission_denied")
        default:
            isScanning = false
            onState?("scan_unavailable")
        }
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard shouldScan, isScanning, let clockMs = clockMs else { return }
        let value = RSSI.doubleValue
        // RSSI 127/-128は使用しない。端末名・広告情報は読み取っても書き出さない。
        guard value.isFinite, (-127...20).contains(value) else { return }
        let time = clockMs()
        guard (0..<RecordingPolicy.maxDurationMs).contains(time) else { return }
        let trace = identities.token(for: peripheral.identifier, atMs: time)
        onObservation?(BLEObservation(traceId: trace, tMs: time, rssi: value))
    }
}