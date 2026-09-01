import Testing
@testable import StillAir

@Suite("ThermalPressure", .tags(.unit, .thermal))
struct ThermalPressureTests {
    @Test("rank is notify value plus one")
    func ranks() {
        #expect(ThermalPressure.nominal.rank == 1)
        #expect(ThermalPressure.moderate.rank == 2)
        #expect(ThermalPressure.heavy.rank == 3)
        #expect(ThermalPressure.trapping.rank == 4)
        #expect(ThermalPressure.sleeping.rank == 5)
    }

    @Test("notify integers map to OSThermalPressureLevel names, not ProcessInfo names")
    func notifyMapping() {
        #expect(ThermalPressure.from(notifyState: 0) == .nominal)
        #expect(ThermalPressure.from(notifyState: 1) == .moderate)
        #expect(ThermalPressure.from(notifyState: 2) == .heavy)
        #expect(ThermalPressure.from(notifyState: 3) == .trapping)
        #expect(ThermalPressure.from(notifyState: 4) == .sleeping)
        #expect(ThermalPressure.from(notifyState: 99) == .nominal)
    }

    @Test("digit only when approaching or throttling")
    func rankDigit() {
        #expect(!ThermalPressure.nominal.showsRankDigit)
        #expect(ThermalPressure.moderate.showsRankDigit)
        #expect(ThermalPressure.heavy.showsRankDigit)
    }

    @Test("menu bar title is temp-only at Nominal; temp plus rank otherwise")
    func menuBarTitle() {
        #expect(ThermalPressure.nominal.menuBarTitle(temperatureText: "72°") == "72°")
        #expect(ThermalPressure.moderate.menuBarTitle(temperatureText: "72°") == "72° 2")
        #expect(ThermalPressure.heavy.menuBarTitle(temperatureText: "61°") == "61° 3")
    }

    @Test("color is nil at Nominal and set for every throttle rank")
    func colorsFromPressureNotTemperature() {
        #expect(ThermalPressure.nominal.menuBarColor == nil)
        #expect(ThermalPressure.moderate.menuBarColor != nil)
        #expect(ThermalPressure.heavy.menuBarColor != nil)
        #expect(ThermalPressure.trapping.menuBarColor != nil)
        #expect(ThermalPressure.sleeping.menuBarColor != nil)
    }
}

@Suite("ThermalStatus", .tags(.unit, .thermal))
struct ThermalStatusTests {
    @Test("menu bar text is a unit formatter only")
    func formatter() {
        #expect(ThermalStatus.menuBarTemperatureText(celsius: 72.4, useFahrenheit: false) == "72°")
        #expect(ThermalStatus.menuBarTemperatureText(celsius: 0, useFahrenheit: true) == "32°")
    }
}
