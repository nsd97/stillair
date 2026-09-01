import Foundation

/// One pressure-level change. Written so you can see *when* throttling happened.
struct ThrottleEvent: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var from: ThermalPressure
    var to: ThermalPressure
    var peakCelsius: Double
    /// ProcessInfo.ThermalState raw value — secondary, not used for color.
    var processThermalRaw: Int
    var lowPowerMode: Bool

    var fromRank: Int { from.rank }
    var toRank: Int { to.rank }
}

/// Ring of throttle transitions in Application Support/StillAir.
///
/// Separate from DiagnosticLogger’s 60s snapshots. Only records edges.
final class ThrottleEventLog: ObservableObject {
    static let shared = ThrottleEventLog()

    @Published private(set) var events: [ThrottleEvent] = []

    private let maxEvents = 200
    private let persistencePath: URL

    init(persistenceDirectory: URL? = nil) {
        let fm = FileManager.default
        let dir: URL
        if let persistenceDirectory {
            dir = persistenceDirectory
        } else {
            let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
            dir = base.appendingPathComponent(AppBrand.applicationSupportName, isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        persistencePath = dir.appendingPathComponent("throttle-events.json")
        events = Self.load(from: persistencePath)
    }

    /// Newest first, capped for the status menu.
    var menuEvents: [ThrottleEvent] {
        Array(events.suffix(20).reversed())
    }

    func append(
        from: ThermalPressure,
        to: ThermalPressure,
        peakCelsius: Double,
        processThermalState: ProcessInfo.ThermalState,
        lowPowerMode: Bool,
        date: Date = Date()
    ) {
        guard from != to else { return }
        let event = ThrottleEvent(
            id: UUID(),
            date: date,
            from: from,
            to: to,
            peakCelsius: peakCelsius,
            processThermalRaw: processThermalState.rawValue,
            lowPowerMode: lowPowerMode
        )
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(events) else { return }
        try? data.write(to: persistencePath, options: .atomic)
    }

    private static func load(from path: URL) -> [ThrottleEvent] {
        guard let data = try? Data(contentsOf: path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([ThrottleEvent].self, from: data)) ?? []
    }
}
