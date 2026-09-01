import ServiceManagement
import SwiftUI

enum AppearanceMode: String, CaseIterable {
    case system
    case light
    case dark

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool = false

    @AppStorage("useFahrenheit") var useFahrenheit = false
    @AppStorage("appearanceMode") var appearanceMode: AppearanceMode = .dark
    @AppStorage("showScrollIndicators") var showScrollIndicators = true
    @AppStorage("detailPanelHeight") var detailPanelHeight: Double = 560
    @AppStorage("showFPS") var showFPS = false
    @AppStorage("showMenuBarTemp") var showMenuBarTemp = true

    static let detailPanelMinHeight: CGFloat = 350
    static let detailPanelMaxHeight: CGFloat = 800
    static let detailPanelDefaultHeight: CGFloat = 560

    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var nsAppearance: NSAppearance? {
        switch appearanceMode {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    private init() {
        syncLaunchAtLogin()
    }

    func syncLaunchAtLogin() {
        let enabled = SMAppService.mainApp.status == .enabled
        if launchAtLogin != enabled {
            launchAtLogin = enabled
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            NSLog("Launch at login failed: \(error)")
            syncLaunchAtLogin()
        }
    }

    func formatTemperature(_ celsius: Double) -> String {
        if useFahrenheit {
            let f = celsius * 9.0 / 5.0 + 32.0
            return String(format: "%.1f°F", f)
        }
        return String(format: "%.1f°C", celsius)
    }
}
