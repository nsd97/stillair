import Darwin
import Foundation
import notify

/// Reads `com.apple.system.thermalpressurelevel` (the 5-level thermald scale).
///
/// `ProcessInfo.thermalState` is too coarse (Moderate+Heavy both show as Fair).
/// Notify can drop intermediate states, so we also poll. Starts at launch — not gated on a helper.
final class ThermalPressureMonitor: ObservableObject {
    static let notifyName = "com.apple.system.thermalpressurelevel"

    @Published private(set) var pressure: ThermalPressure = .nominal
    @Published private(set) var processThermalState: ProcessInfo.ThermalState = .nominal

    weak var fanMonitor: FanMonitor?
    let eventLog: ThrottleEventLog

    private var notifyToken: Int32 = 0
    private var notifyRegistered = false
    private var pollTimer: Timer?
    private var thermalObserver: NSObjectProtocol?
    private var started = false

    init(eventLog: ThrottleEventLog = .shared) {
        self.eventLog = eventLog
    }

    deinit {
        stop()
    }

    func start() {
        guard !started else { return }
        started = true

        // Docs: you must read thermalState before registering the change notification.
        processThermalState = ProcessInfo.processInfo.thermalState

        registerNotify()
        thermalObserver = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.processThermalState = ProcessInfo.processInfo.thermalState
        }

        apply(Self.readNotifyPressure())

        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.apply(Self.readNotifyPressure())
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if notifyRegistered {
            notify_cancel(notifyToken)
            notifyRegistered = false
        }
        if let thermalObserver {
            NotificationCenter.default.removeObserver(thermalObserver)
            self.thermalObserver = nil
        }
        started = false
    }

    /// Apply a pressure reading. Logs an event on every edge, including launch if already non-nominal.
    func apply(_ next: ThermalPressure) {
        let previous = pressure
        guard previous != next else { return }
        pressure = next
        eventLog.append(
            from: previous,
            to: next,
            peakCelsius: fanMonitor?.peakTemperature ?? 0,
            processThermalState: processThermalState,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }

    static func readNotifyPressure() -> ThermalPressure {
        var token: Int32 = 0
        guard notify_register_check(notifyName, &token) == NOTIFY_STATUS_OK else {
            return .nominal
        }
        defer { notify_cancel(token) }
        var state: UInt64 = 0
        notify_get_state(token, &state)
        return ThermalPressure.from(notifyState: state)
    }

    private func registerNotify() {
        var token: Int32 = 0
        let status = notify_register_dispatch(Self.notifyName, &token, DispatchQueue.main) { [weak self] innerToken in
            var state: UInt64 = 0
            notify_get_state(innerToken, &state)
            self?.apply(ThermalPressure.from(notifyState: state))
        }
        guard status == NOTIFY_STATUS_OK else { return }
        notifyToken = token
        notifyRegistered = true
    }
}
