import Foundation
import CoreLocation

final class LocationRecorder: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var latest: CLLocation?
    private var heading: CLHeading?
    private var origin: CLLocationCoordinate2D?
    private var lastUsable: (position: [Double], tMs: Int, accuracy: Double)?
    private var segment = 0
    private var onStatus: ((String) -> Void)?
    var currentSegment: String { "segment-\(segment)" }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
    }

    func start(status: @escaping (String) -> Void) {
        onStatus = status
        latest = nil
        heading = nil
        origin = nil
        lastUsable = nil
        segment = 0
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else { beginIfAuthorized() }
    }

    private func beginIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        case .denied, .restricted: onStatus?("location_unavailable")
        default: break
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        onStatus = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        beginIfAuthorized()
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let newest = locations.last { latest = newest }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onStatus?("location_unavailable")
    }

    /// GPS座標はメモリで相対座標に変換し、exportへは含めない。
    func sample(atMs: Int, stepsDelta: Int?, stepsIntervalMs: Int?) -> SelfSample {
        let location = latest
        let age = location.map { max(0, Int(Date().timeIntervalSince($0.timestamp) * 1000)) } ?? 900_000
        let accuracy = location?.horizontalAccuracy ?? -1
        let validity = RecordingPolicy.quality(accuracy: accuracy, ageMs: age)
        var p: [Double]? = nil
        var exportedAccuracy: Double? = accuracy >= 0 && accuracy.isFinite ? accuracy : nil
        if let location = location, validity != "unavailable" {
            if origin == nil { origin = location.coordinate }
            if let origin = origin {
                let earth = 6_378_137.0
                let lat0 = origin.latitude * .pi / 180.0
                let deltaLat = (location.coordinate.latitude - origin.latitude) * .pi / 180.0
                var deltaLon = (location.coordinate.longitude - origin.longitude) * .pi / 180.0
                deltaLon = atan2(sin(deltaLon), cos(deltaLon))
                let east = earth * cos(lat0) * deltaLon
                let south = -earth * deltaLat
                let candidate = [east, 0.0, south]
                if let previous = lastUsable {
                    let gap = Double(max(1, atMs - previous.tMs)) / 1000
                    let distance = hypot(east - previous.position[0], south - previous.position[2])
                    if distance > max(15 * gap, previous.accuracy + accuracy + 5) || hypot(east, south) > 2_000 {
                        segment += 1
                        self.origin = location.coordinate
                        p = [0, 0, 0]
                    } else { p = candidate }
                } else { p = candidate }
                if validity == "usable", let p = p {
                    lastUsable = (position: p, tMs: atMs, accuracy: accuracy)
                }
            }
        } else {
            exportedAccuracy = nil
        }
        let head = heading
        let trueHeading = head?.trueHeading ?? -1
        let headingAccuracy = head?.headingAccuracy ?? -1
        let headingValid = trueHeading.isFinite && trueHeading >= 0 &&
                           headingAccuracy.isFinite && headingAccuracy >= 0
        return SelfSample(tMs: atMs, segmentId: currentSegment, source: "coreLocation",
                          positionM: p, horizontalAccuracyM: exportedAccuracy,
                          ageMs: min(age, 900_000), quality: validity,
                          headingDeg: headingValid ? trueHeading : nil,
                          headingAccuracyDeg: headingValid ? headingAccuracy : nil,
                          stepsDelta: stepsDelta, stepsIntervalMs: stepsIntervalMs)
    }
}