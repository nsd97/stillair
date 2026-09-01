import Foundation

/// Temperature text helpers. Color lives on `ThermalPressure` — never on °C.
enum ThermalStatus {
    /// Compact monochrome readout for the status item (integer degrees).
    static func menuBarTemperatureText(celsius: Double, useFahrenheit: Bool) -> String {
        if useFahrenheit {
            let f = celsius * 9.0 / 5.0 + 32.0
            return "\(Int(f.rounded()))°"
        }
        return "\(Int(celsius.rounded()))°"
    }
}
