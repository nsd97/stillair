import Cocoa
import Combine
import SwiftUI

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let statusMenu: NSMenu
    private var settingsSub: AnyCancellable?
    private var statusItemSubs = Set<AnyCancellable>()
    private var lastStatusItemSignature: String?

    private var settingsWindow: NSWindow?

    private let systemInfo: SystemInfo
    private let fanMonitor: FanMonitor
    private let thermalMonitor: ThermalPressureMonitor
    private let eventLog: ThrottleEventLog
    private let updateChecker: UpdateChecker

    init(
        fanMonitor: FanMonitor,
        thermalMonitor: ThermalPressureMonitor,
        eventLog: ThrottleEventLog,
        systemInfo: SystemInfo,
        updateChecker: UpdateChecker
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusMenu = NSMenu()
        self.systemInfo = systemInfo
        self.fanMonitor = fanMonitor
        self.thermalMonitor = thermalMonitor
        self.eventLog = eventLog
        self.updateChecker = updateChecker

        super.init()

        statusMenu.delegate = self
        statusItem.menu = statusMenu

        if let button = statusItem.button {
            button.imagePosition = .imageLeft
        }
        updateStatusItem()

        settingsSub = AppSettings.shared.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.settingsWindow?.contentView?.appearance = AppSettings.shared.nsAppearance
                self.updateStatusItem()
            }
        }

        fanMonitor.$peakTemperature
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &statusItemSubs)

        thermalMonitor.$pressure
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &statusItemSubs)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let peak = fanMonitor.peakTemperature
        let pressure = thermalMonitor.pressure
        let settings = AppSettings.shared
        let tempText = settings.showMenuBarTemp
            ? ThermalStatus.menuBarTemperatureText(celsius: peak, useFahrenheit: settings.useFahrenheit)
            : ""
        let title = settings.showMenuBarTemp ? pressure.menuBarTitle(temperatureText: tempText) : ""
        let signature = "\(title)|\(settings.useFahrenheit)|\(pressure.rank)|\(settings.showMenuBarTemp)"
        guard signature != lastStatusItemSignature else { return }
        lastStatusItemSignature = signature

        let image = NSImage(systemSymbolName: "thermometer.medium", accessibilityDescription: nil)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = title.isEmpty ? .imageOnly : .imageLeft

        let font = NSFont.menuBarFont(ofSize: 0)
        var attrs: [NSAttributedString.Key: Any] = [.font: font]
        if let color = pressure.menuBarColor {
            attrs[.foregroundColor] = color
        }
        button.attributedTitle = NSAttributedString(string: title, attributes: attrs)

        let spoken: String
        if settings.showMenuBarTemp {
            spoken = "\(AppBrand.displayName), \(tempText), level \(pressure.rank), \(pressure.label)"
        } else {
            spoken = AppBrand.displayName
        }
        button.toolTip = spoken
        button.setAccessibilityLabel(spoken)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        AppSettings.shared.syncLaunchAtLogin()
        StillAirStatusMenuBuilder.rebuild(
            menu: menu,
            monitor: fanMonitor,
            pressure: thermalMonitor.pressure,
            events: eventLog.menuEvents,
            settings: AppSettings.shared,
            updateAvailable: updateChecker.updateAvailable,
            actions: .init(
                target: self,
                openSettings: #selector(openSettings(_:)),
                quit: #selector(quitApp(_:))
            )
        )
    }

    func menuWillOpen(_ menu: NSMenu) {
        fanMonitor.isMenuVisible = true
        fanMonitor.updatePollInterval()
    }

    func menuDidClose(_ menu: NSMenu) {
        fanMonitor.isMenuVisible = false
        fanMonitor.updatePollInterval()
    }

    @objc private func openSettings(_ sender: Any?) {
        showSettingsWindow()
    }

    @objc private func quitApp(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    func showSettingsWindow() {
        if settingsWindow == nil {
            let root = SettingsView(
                settings: AppSettings.shared,
                updateChecker: updateChecker,
                fanMonitor: fanMonitor,
                systemInfo: systemInfo
            )
            let hosting = NSHostingController(rootView: AppearanceHost(content: root))
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 420),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "\(AppBrand.displayName) Settings"
            window.contentViewController = hosting
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 380, height: 420))
            window.center()
            settingsWindow = window
        }

        settingsWindow?.contentView?.appearance = AppSettings.shared.nsAppearance
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
