import Foundation
import CoreLocation

/// Holt die GPS-Position so genau wie möglich und misst einzelne Punkte.
@MainActor
final class LocationEngine: NSObject, ObservableObject {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var fullAccuracy = true
    /// Letzter GPS-Wert (auch ungenaue)
    @Published private(set) var current: CLLocation?
    @Published private(set) var isMeasuring = false

    /// GPS-Werte, die ungenauer sind, werden nicht verwendet (Meter).
    static let maxAccuracy: CLLocationAccuracy = 10
    /// So lange wird mindestens gemessen (Sekunden).
    static let minSeconds: Double = 4
    /// Spätestens dann wird aufgegeben, wenn kein gutes Signal kommt.
    static let maxSeconds: Double = 12

    private let manager = CLLocationManager()
    /// Gute Werte der letzten Sekunden, damit eine Messung sofort Daten hat.
    private var recent: [CLLocation] = []
    private var samples: [CLLocation] = []

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .fitness
        manager.pausesLocationUpdatesAutomatically = false
        fullAccuracy = manager.accuracyAuthorization == .fullAccuracy
    }

    var isAllowed: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    func start() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else if isAllowed {
            manager.startUpdatingLocation()
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    /// Misst die aktuelle Position: sammelt einige Sekunden gute GPS-Werte und mittelt sie.
    /// Gibt nil zurück, wenn kein genaues Signal kam.
    func measurePoint() async -> MeasuredPoint? {
        start()
        isMeasuring = true
        defer { isMeasuring = false }

        // Die guten Werte der letzten 3 Sekunden zählen schon mit.
        let cutoff = Date().addingTimeInterval(-3)
        samples = recent.filter { $0.timestamp > cutoff }

        let begin = Date()
        while true {
            try? await Task.sleep(nanoseconds: 500_000_000)
            let elapsed = Date().timeIntervalSince(begin)
            if elapsed >= Self.minSeconds && samples.count >= 3 { break }
            if elapsed >= Self.maxSeconds { break }
        }

        let result = MeasuredPoint.average(samples)
        samples = []
        return result
    }

    fileprivate func receive(_ locations: [CLLocation]) {
        for loc in locations {
            // Ungültige oder veraltete Werte überspringen
            guard loc.horizontalAccuracy >= 0,
                  abs(loc.timestamp.timeIntervalSinceNow) < 2 else { continue }
            current = loc
            guard loc.horizontalAccuracy <= Self.maxAccuracy else { continue }
            recent.append(loc)
            if isMeasuring { samples.append(loc) }
        }
        let keep = Date().addingTimeInterval(-10)
        recent.removeAll { $0.timestamp < keep }
    }

    fileprivate func authorizationChanged(_ status: CLAuthorizationStatus, full: Bool) {
        authorization = status
        fullAccuracy = full
        if isAllowed { manager.startUpdatingLocation() }
    }
}

extension LocationEngine: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.receive(locations) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let full = manager.accuracyAuthorization == .fullAccuracy
        Task { @MainActor in self.authorizationChanged(status, full: full) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Kurze Aussetzer ignorieren; das GPS liefert danach weiter.
    }
}
