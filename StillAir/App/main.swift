import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    let fanMonitor = FanMonitor()
    let thermalMonitor = ThermalPressureMonitor()
    let systemInfo = SystemInfo()
    let memoryInfo = MemoryInfo()
    let batteryInfo = BatteryInfo()
    let cpuInfo = CpuInfo()

    func applicationDidFinishLaunching(_ notification: Notification) {
        fanMonitor.startMonitoring()

        thermalMonitor.fanMonitor = fanMonitor
        thermalMonitor.start()

        DiagnosticLogger.shared.fanMonitor = fanMonitor
        DiagnosticLogger.shared.thermalMonitor = thermalMonitor
        DiagnosticLogger.shared.startLogging()

        statusBarController = StatusBarController(
            fanMonitor: fanMonitor,
            thermalMonitor: thermalMonitor,
            eventLog: thermalMonitor.eventLog,
            systemInfo: systemInfo
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        DiagnosticLogger.shared.stopLogging()
        thermalMonitor.stop()
        fanMonitor.stopMonitoring()
        systemInfo.stopMonitoring()
        memoryInfo.stopMonitoring()
        batteryInfo.stopMonitoring()
        cpuInfo.stopMonitoring()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
