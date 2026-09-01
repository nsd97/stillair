import AppKit
import SwiftUI

/// The five macOS thermal-pressure levels from `com.apple.system.thermalpressurelevel`.
///
/// Raw values match `OSThermalPressureLevel` on macOS (0–4). Display rank is 1–5.
/// Color and the menu-bar digit come from this value only — never from °C.
enum ThermalPressure: Int, Codable, CaseIterable, Equatable {
    case nominal = 0
    case moderate = 1
    case heavy = 2
    case trapping = 3
    case sleeping = 4

    /// User-facing 1–5. Notify `0` → `1`, `4` → `5`.
    var rank: Int { rawValue + 1 }

    var label: String {
        switch self {
        case .nominal: return "Nominal"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .trapping: return "Trapping"
        case .sleeping: return "Sleeping"
        }
    }

    /// Rank digit is hidden at Nominal so the menu bar stays a plain temperature.
    var showsRankDigit: Bool { self != .nominal }

    /// Menu-bar tint. `nil` means system default (Nominal).
    var menuBarColor: NSColor? {
        switch self {
        case .nominal:
            return nil
        case .moderate:
            return NSColor.systemYellow
        case .heavy:
            return NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.16, alpha: 1)
        case .trapping:
            return NSColor.systemRed
        case .sleeping:
            return NSColor(calibratedRed: 0.62, green: 0.04, blue: 0.12, alpha: 1)
        }
    }

    var swiftUIColor: Color {
        if let menuBarColor {
            return Color(nsColor: menuBarColor)
        }
        return Color.primary
    }

    func menuBarTitle(temperatureText: String) -> String {
        if showsRankDigit {
            return "\(temperatureText) \(rank)"
        }
        return temperatureText
    }

    static func from(notifyState: UInt64) -> ThermalPressure {
        ThermalPressure(rawValue: Int(notifyState)) ?? .nominal
    }
}
