import Foundation
import CoreLocation

/// Die Schläger zur Auswahl.
enum Clubs {
    static let all = [
        "Driver", "Holz 3", "Holz 5", "Holz 7", "Hybrid 3",
        "Eisen 4", "Eisen 5", "Eisen 6", "Eisen 7", "Eisen 8", "Eisen 9",
        "PW", "GW", "SW", "LW"
    ]
}

/// Ein gemessener Punkt auf dem Platz (Mittelwert aus mehreren GPS-Werten).
struct MeasuredPoint: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// Geschätzte Genauigkeit in Metern
    var accuracy: Double
    var date: Date

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    func distance(to other: MeasuredPoint) -> Double {
        location.distance(from: other.location)
    }

    func distance(to other: CLLocation) -> Double {
        location.distance(from: other)
    }

    /// Mittelt die GPS-Werte. Genauere Werte zählen stärker.
    static func average(_ samples: [CLLocation]) -> MeasuredPoint? {
        guard !samples.isEmpty else { return nil }
        var sumW = 0.0, lat = 0.0, lon = 0.0
        for s in samples {
            let acc = max(s.horizontalAccuracy, 1)
            let w = 1 / (acc * acc)
            sumW += w
            lat += s.coordinate.latitude * w
            lon += s.coordinate.longitude * w
        }
        // Grobe Schätzung der Genauigkeit: Mittelwert der GPS-Angaben,
        // durch das Mitteln etwas besser, aber höchstens halbiert, weil
        // aufeinanderfolgende GPS-Fehler sich ähneln.
        let accs = samples.map(\.horizontalAccuracy).sorted()
        let median = accs[accs.count / 2]
        let factor = Double(min(samples.count, 4)).squareRoot()
        return MeasuredPoint(
            latitude: lat / sumW,
            longitude: lon / sumW,
            accuracy: max(median / factor, 1.5),
            date: Date()
        )
    }
}

/// Ein gemessener Schlag.
struct Shot: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var club: String
    /// Länge in Metern
    var meters: Double
    /// Mögliche Abweichung in Metern (±)
    var uncertainty: Double
}

enum Meters {
    static func text(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}
