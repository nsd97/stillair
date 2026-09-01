import Foundation
import Testing
@testable import StillAir

@Suite("ThrottleEventLog", .tags(.unit, .thermal))
struct ThrottleEventLogTests {
    @Test("append records an edge and skips same-to-same")
    func appendOnEdge() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = ThrottleEventLog(persistenceDirectory: dir)

        log.append(
            from: .nominal,
            to: .nominal,
            peakCelsius: 90,
            processThermalState: .nominal,
            lowPowerMode: false
        )
        #expect(log.events.isEmpty)

        log.append(
            from: .nominal,
            to: .heavy,
            peakCelsius: 55,
            processThermalState: .fair,
            lowPowerMode: true
        )
        #expect(log.events.count == 1)
        #expect(log.events[0].from == .nominal)
        #expect(log.events[0].to == .heavy)
        #expect(log.events[0].toRank == 3)
        #expect(log.events[0].peakCelsius == 55)
        #expect(log.events[0].lowPowerMode)
        #expect(log.events[0].processThermalRaw == ProcessInfo.ThermalState.fair.rawValue)
    }

    @Test("persists and reloads")
    func persists() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = ThrottleEventLog(persistenceDirectory: dir)
        log.append(
            from: .moderate,
            to: .heavy,
            peakCelsius: 70,
            processThermalState: .fair,
            lowPowerMode: false
        )

        let reloaded = ThrottleEventLog(persistenceDirectory: dir)
        #expect(reloaded.events.count == 1)
        #expect(reloaded.events[0].to == .heavy)
    }

    @Test("apply logs launch-time non-nominal as Nominal → current")
    func monitorLaunchEdge() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let log = ThrottleEventLog(persistenceDirectory: dir)
        let monitor = ThermalPressureMonitor(eventLog: log)

        monitor.apply(.nominal)
        #expect(log.events.isEmpty)

        monitor.apply(.moderate)
        #expect(log.events.count == 1)
        #expect(log.events[0].from == .nominal)
        #expect(log.events[0].to == .moderate)

        monitor.apply(.moderate)
        #expect(log.events.count == 1)
    }
}

@Suite("StillAirStatusMenuBuilder", .tags(.unit, .thermal))
struct StillAirStatusMenuBuilderTests {
    @Test("log line includes ranks and level name")
    func logLine() {
        let event = ThrottleEvent(
            id: UUID(),
            date: Date(timeIntervalSince1970: 0),
            from: .moderate,
            to: .heavy,
            peakCelsius: 61,
            processThermalRaw: 1,
            lowPowerMode: true
        )
        let line = StillAirStatusMenuBuilder.logLine(event: event, useFahrenheit: false)
        #expect(line.contains("2→3"))
        #expect(line.contains("Heavy"))
        #expect(line.contains("61°"))
        #expect(line.contains("LPM"))
    }
}
