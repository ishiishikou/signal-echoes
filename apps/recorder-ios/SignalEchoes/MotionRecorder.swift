import Foundation
import CoreMotion

final class MotionRecorder {
    private let pedometer = CMPedometer()
    private var lastCount: Int?
    private var currentCount: Int?
    private var lastSampleMs: Int?

    func start() {
        lastCount = nil
        currentCount = nil
        lastSampleMs = nil
        guard CMPedometer.isStepCountingAvailable() else { return }
        pedometer.startUpdates(from: Date()) { [weak self] data, _ in
            DispatchQueue.main.async {
                guard let self = self, let data = data else { return }
                self.currentCount = max(0, data.numberOfSteps.intValue)
            }
        }
    }
    func sample(atMs: Int) -> (stepsDelta: Int?, intervalMs: Int?) {
        defer { lastSampleMs = atMs; lastCount = currentCount }
        guard let count = currentCount, let before = lastCount else {
            return (nil, nil)
        }
        return (max(0, count - before), atMs - (lastSampleMs ?? atMs))
    }
    func stop() { pedometer.stopUpdates(); lastCount = nil; currentCount = nil }
}