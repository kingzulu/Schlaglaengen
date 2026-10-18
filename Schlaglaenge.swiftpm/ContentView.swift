import SwiftUI
import CoreLocation
import UIKit

/// Hauptbildschirm: Schläger wählen, am Abschlag tippen, am Ball tippen.
struct ContentView: View {
    @EnvironmentObject private var store: ShotStore
    @EnvironmentObject private var gps: LocationEngine
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("schlaglaenge-club") private var club = "Driver"
    @State private var lastShot: Shot?
    @State private var message: String?
    @State private var showStats = false
    @State private var showAbout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !gps.isAllowed && gps.authorization != .notDetermined {
                        PermissionCard()
                    } else {
                        GPSStatusCard()
                    }
                    clubCard
                    statusCard
                    mainButton
                    if store.openStart != nil {
                        Button("Loch beenden (nichts messen)", role: .destructive) {
                            store.openStart = nil
                            message = nil
                        }
                        .font(.subheadline)
                        .disabled(gps.isMeasuring)
                    }
                    if let lastShot {
                        LastShotCard(shot: lastShot)
                    }
                    Text("Wähle den Schläger, tippe vor dem Abschlag auf „Abschlag“ und am Ball auf „Am Ball“. Bleib beim Messen kurz ruhig stehen.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .modifier(BrandToolbar(onBrand: { showAbout = true }, onStats: { showStats = true }))
            .toolbarBackground(Color.zuluNavy, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(isPresented: $showStats) {
                StatsView().environmentObject(store)
            }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
        }
        .onAppear {
            gps.start()
            // Gemerkter Schläger gibt es nicht mehr (z. B. altes „Hybrid“).
            if !Clubs.all.contains(club) {
                club = club == "Hybrid" ? "Hybrid 3" : "Driver"
            }
        }
        .onChange(of: scenePhase) { phase in
            // GPS nur laufen lassen, solange die App offen ist (spart Akku).
            if phase == .active { gps.start() } else if phase == .background { gps.stop() }
        }
    }

    // MARK: - Schläger

    private var clubCard: some View {
        HStack {
            Text("Schläger")
                .font(.headline)
            Spacer()
            Picker("Schläger", selection: $club) {
                ForEach(Clubs.all, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .tint(Color("ZuluBlue"))
        }
        .padding()
        .background(cardBackground)
    }

    // MARK: - Stand des Schlags

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let start = store.openStart {
                Text("Start gemerkt um \(start.date.formatted(date: .omitted, time: .shortened)) (± \(Meters.text(start.accuracy)) m)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let here = gps.current {
                    (Text("Bisher ca. ")
                        + Text("\(Meters.text(start.distance(to: here))) m").bold())
                        .font(.title3)
                        .monospacedDigit()
                } else {
                    Text("Geh zum Ball …").font(.title3)
                }
            } else {
                Text("Bereit für den Abschlag")
                    .font(.title3.weight(.semibold))
                Text("Noch kein Startpunkt gemerkt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let message {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(cardBackground)
    }

    // MARK: - Großer Knopf

    private var mainButton: some View {
        Button(action: measure) {
            HStack(spacing: 12) {
                if gps.isMeasuring {
                    ProgressView().tint(.zuluYellow)
                    Text("Messe … bitte still stehen")
                } else if store.openStart == nil {
                    Image(systemName: "flag")
                    Text("Abschlag")
                } else {
                    Image(systemName: "figure.golf")
                    Text("Am Ball – Schlag messen")
                }
            }
            .font(.title3.weight(.bold))
            .foregroundColor(.zuluYellow)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.zuluNavy)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .disabled(gps.isMeasuring || !gps.isAllowed)
        .opacity(gps.isAllowed ? 1 : 0.5)
    }

    private func measure() {
        message = nil
        Task {
            guard let point = await gps.measurePoint() else {
                message = "Kein genaues GPS-Signal. Kurz warten und nochmal tippen."
                return
            }
            if store.openStart == nil {
                store.openStart = point
            } else if let shot = store.finishShot(at: point, club: club) {
                lastShot = shot
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - GPS-Anzeige

private struct GPSStatusCard: View {
    @EnvironmentObject private var gps: LocationEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Circle().fill(color).frame(width: 12, height: 12)
                Text(text).font(.subheadline.weight(.semibold))
                Spacer()
            }
            if !gps.fullAccuracy {
                Text("„Genauer Standort“ ist aus. Bitte in den Einstellungen unter Datenschutz › Ortungsdienste › ZG-Schlaglänge einschalten.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    private var accuracy: Double? {
        gps.current.map(\.horizontalAccuracy)
    }

    private var text: String {
        guard let accuracy else { return "GPS sucht Satelliten …" }
        let value = "GPS ± \(Meters.text(accuracy)) m"
        if accuracy <= 5 { return value + " – sehr gut" }
        if accuracy <= LocationEngine.maxAccuracy { return value + " – gut" }
        return value + " – zu ungenau, kurz warten"
    }

    private var color: Color {
        guard let accuracy else { return .gray }
        if accuracy <= 5 { return Color("ZuluBlue") }
        if accuracy <= LocationEngine.maxAccuracy { return .zuluYellow }
        return .red
    }
}

private struct PermissionCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kein Zugriff auf den Standort")
                .font(.headline)
            Text("Ohne GPS kann die App nicht messen. Erlaube den Standort „Beim Verwenden der App“ und schalte „Genauer Standort“ ein.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Einstellungen öffnen") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .tint(Color("ZuluBlue"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Letzter Schlag

private struct LastShotCard: View {
    let shot: Shot

    var body: some View {
        VStack(spacing: 4) {
            Text("Letzter Schlag · \(shot.club)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("ZuluBlue"))
            (Text(Meters.text(shot.meters)).font(.system(size: 56, weight: .bold))
                + Text(" m").font(.title2).foregroundColor(.secondary))
                .monospacedDigit()
            Text("± \(Meters.text(shot.uncertainty)) m")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Kopfzeile

/// Logo und Titel links, „Statistik“ rechts in der Navy-Leiste.
private struct BrandToolbar: ViewModifier {
    let onBrand: () -> Void
    let onStats: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // Ab iOS 26 legt das System sonst einen Glas-Rahmen um Logo und Titel.
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) { brandButton }
                    .sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .primaryAction) { statsButton }
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigationBarLeading) { brandButton }
                ToolbarItem(placement: .primaryAction) { statsButton }
            }
        }
    }

    // Tipp auf Logo oder Titel öffnet die Info-Seite zu Zulu Golf.
    private var brandButton: some View {
        Button(action: onBrand) { BrandTitle() }
            .buttonStyle(.plain)
            .accessibilityHint("Zeigt Infos zu Zulu Golf")
    }

    private var statsButton: some View {
        Button("Statistik", action: onStats)
            .tint(.white)
    }
}

private struct BrandTitle: View {
    var body: some View {
        HStack(spacing: 10) {
            Image("ZGLogo")
                .renderingMode(.original)
                .resizable()
                .aspectRatio(480.0 / 306.0, contentMode: .fit)
                .frame(width: 38, height: 24)
                .fixedSize()
                .accessibilityLabel("Zulu Golf")
            Text("Schlaglänge")
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
