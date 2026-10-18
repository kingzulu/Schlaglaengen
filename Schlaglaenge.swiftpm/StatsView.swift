import SwiftUI

/// Durchschnitt pro Schläger und Liste aller Schläge.
struct StatsView: View {
    @EnvironmentObject private var store: ShotStore
    @Environment(\.dismiss) private var dismiss

    private var usedClubs: [String] {
        Clubs.all.filter { store.stats(for: $0) != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                if store.shots.isEmpty {
                    Text("Noch keine Schläge gemessen.")
                        .foregroundStyle(.secondary)
                } else {
                    Section("Durchschnitt pro Schläger") {
                        ForEach(usedClubs, id: \.self) { club in
                            if let s = store.stats(for: club) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(club).font(.headline)
                                        Text("\(s.count) Schläge · weitester \(Meters.text(s.longest)) m")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    (Text(Meters.text(s.average)).font(.title2.weight(.bold))
                                        + Text(" m").font(.subheadline).foregroundColor(.secondary))
                                        .monospacedDigit()
                                }
                            }
                        }
                    }

                    Section {
                        ForEach(store.shots) { shot in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shot.club).font(.subheadline.weight(.semibold))
                                    Text(shot.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Meters.text(shot.meters)) m")
                                    .font(.headline)
                                    .monospacedDigit()
                                Text("± \(Meters.text(shot.uncertainty))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .onDelete { offsets in
                            store.delete(Set(offsets.map { store.shots[$0].id }))
                        }
                    } header: {
                        Text("Alle Schläge")
                    } footer: {
                        Text("Zum Löschen eines Fehlschlags nach links wischen.")
                    }
                }
            }
            .navigationTitle("Statistik")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
