import AppKit
import SwiftUI

/// Status menu: current pressure + always-on throttle log. No fan or Cool modes.
enum StillAirStatusMenuBuilder {
    enum ItemTag: Int {
        case settings = 200
        case quit = 201
    }

    struct Actions {
        let target: AnyObject
        let openSettings: Selector
        let quit: Selector
    }

    static func rebuild(
        menu: NSMenu,
        monitor: FanMonitor,
        pressure: ThermalPressure,
        events: [ThrottleEvent],
        settings: AppSettings,
        actions: Actions
    ) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        if let error = monitor.smcError {
            appendDisabledCaption(menu: menu, title: "SMC Error")
            appendDisabledCaption(menu: menu, title: error)
            menu.addItem(.separator())
            appendFooter(menu: menu, actions: actions)
            return
        }

        appendStatusHeader(menu: menu, monitor: monitor, pressure: pressure, settings: settings)

        menu.addItem(.separator())

        if #available(macOS 14.0, *) {
            menu.addItem(.sectionHeader(title: "Throttle log"))
        } else {
            appendDisabledCaption(menu: menu, title: "Throttle log")
        }

        if events.isEmpty {
            appendDisabledCaption(menu: menu, title: "No throttling yet.")
        } else {
            for event in events {
                appendDisabledCaption(menu: menu, title: logLine(event: event, useFahrenheit: settings.useFahrenheit))
            }
        }

        menu.addItem(.separator())
        appendFooter(menu: menu, actions: actions)
    }

    static func logLine(event: ThrottleEvent, useFahrenheit: Bool) -> String {
        let time = logTimeFormatter.string(from: event.date)
        let temp = ThermalStatus.menuBarTemperatureText(
            celsius: event.peakCelsius,
            useFahrenheit: useFahrenheit
        )
        var line = "\(time)  \(event.fromRank)→\(event.toRank)  \(event.to.label)  \(temp)"
        if event.lowPowerMode {
            line += "  LPM"
        }
        return line
    }

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private static func appendStatusHeader(
        menu: NSMenu,
        monitor: FanMonitor,
        pressure: ThermalPressure,
        settings: AppSettings
    ) {
        let temp = settings.formatTemperature(monitor.peakTemperature)
        let title: String
        if pressure.showsRankDigit {
            title = "\(temp)  \(pressure.rank)  \(pressure.label)"
        } else {
            title = "\(temp)  \(pressure.label)"
        }

        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if let color = pressure.menuBarColor {
            item.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.menuFont(ofSize: 0),
                    .foregroundColor: color,
                ]
            )
        }
        menu.addItem(item)

        if !monitor.peakTemperatureLabel.isEmpty {
            appendDisabledCaption(menu: menu, title: monitor.peakTemperatureLabel)
        }
    }

    private static func appendDisabledCaption(menu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private static func appendFooter(
        menu: NSMenu,
        actions: Actions
    ) {
        let settings = NSMenuItem(
            title: "Settings…",
            action: actions.openSettings,
            keyEquivalent: ","
        )
        settings.target = actions.target
        settings.tag = ItemTag.settings.rawValue
        settings.isEnabled = true
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title: "Quit \(AppBrand.displayName)",
            action: actions.quit,
            keyEquivalent: "q"
        )
        quit.target = actions.target
        quit.tag = ItemTag.quit.rawValue
        quit.isEnabled = true
        menu.addItem(quit)
    }
}
