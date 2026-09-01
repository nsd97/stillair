import AppKit
import Foundation

struct DiagnosticReport: Codable {
    let exportDate: Date
    let appVersion: String
    let system: SystemSnapshot
    let settings: SettingsSnapshot
    let sleepIntervals: [SleepInterval]
    let history: [DiagnosticSample]
}

struct SystemSnapshot: Codable {
    let machineModel: String
    let chipName: String
    let ramAmount: String
    let macOSVersion: String
    let uptime: String
    let diskUsage: String
}

struct SettingsSnapshot: Codable {
    let useFahrenheit: Bool
    let showMenuBarTemp: Bool
}

enum DiagnosticExporter {
    static func export(
        logger: DiagnosticLogger,
        systemInfo: SystemInfo
    ) {
        let settings = AppSettings.shared

        let report = DiagnosticReport(
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            system: SystemSnapshot(
                machineModel: systemInfo.machineModel,
                chipName: systemInfo.chipName,
                ramAmount: systemInfo.ramAmount,
                macOSVersion: systemInfo.macOSVersion,
                uptime: systemInfo.uptime,
                diskUsage: systemInfo.diskUsage
            ),
            settings: SettingsSnapshot(
                useFahrenheit: settings.useFahrenheit,
                showMenuBarTemp: settings.showMenuBarTemp
            ),
            sleepIntervals: logger.sleepIntervalsSnapshot(),
            history: logger.snapshot()
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(report) else {
            NSLog("DiagnosticExporter: failed to encode report")
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "StillAir-Diagnostics-\(dateStr).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try data.write(to: url, options: .atomic)
            NSLog("DiagnosticExporter: saved report to \(url.path)")
        } catch {
            NSLog("DiagnosticExporter: failed to write report — \(error)")
        }
    }
}
