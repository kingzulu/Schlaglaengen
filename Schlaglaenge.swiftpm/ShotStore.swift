import Foundation

/// Hält die Schläge und den gemerkten Startpunkt und speichert alles sofort auf dem iPhone.
@MainActor
final class ShotStore: ObservableObject {
    @Published var shots: [Shot] {
        didSet { save(shots, key: Self.shotsKey) }
    }

    /// Wo der aktuelle Schlag begonnen hat. Leer = kein Schlag offen.
    @Published var openStart: MeasuredPoint? {
        didSet { save(openStart, key: Self.startKey) }
    }

    private static let shotsKey = "schlaglaenge-shots-v1"
    private static let startKey = "schlaglaenge-start-v1"

    init() {
        var loaded = Self.load([Shot].self, key: Self.shotsKey) ?? []
        // Früher hieß „Hybrid 3“ nur „Hybrid“.
        for i in loaded.indices where loaded[i].club == "Hybrid" {
            loaded[i].club = "Hybrid 3"
        }
        shots = loaded
        openStart = Self.load(MeasuredPoint.self, key: Self.startKey)
    }

    /// Beendet den offenen Schlag am Punkt `end` und gibt ihn zurück.
    func finishShot(at end: MeasuredPoint, club: String) -> Shot? {
        guard let start = openStart else { return nil }
        let meters = start.distance(to: end)
        let uncertainty = (start.accuracy * start.accuracy + end.accuracy * end.accuracy).squareRoot()
        let shot = Shot(date: Date(), club: club, meters: meters, uncertainty: uncertainty)
        shots.insert(shot, at: 0)
        // Der Ball liegt hier: Das ist zugleich der Start des nächsten Schlags.
        openStart = end
        return shot
    }

    func delete(_ ids: Set<Shot.ID>) {
        shots.removeAll { ids.contains($0.id) }
    }

    /// Durchschnitt, Anzahl und weitester Schlag pro Schläger.
    func stats(for club: String) -> (average: Double, count: Int, longest: Double)? {
        let list = shots.filter { $0.club == club }
        guard !list.isEmpty else { return nil }
        let total = list.reduce(0) { $0 + $1.meters }
        return (total / Double(list.count), list.count, list.map(\.meters).max() ?? 0)
    }

    private func save<T: Encodable>(_ value: T?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
