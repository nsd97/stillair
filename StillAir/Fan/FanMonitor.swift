import Cocoa
import Combine

/// SMC temperature polling for the menu bar. No fan control.
final class FanMonitor: ObservableObject {
    @Published var sensors: [TemperatureSensor] = []
    @Published var smcError: String?

    @Published var peakTemperature: Double = 0
    @Published var peakTemperatureLabel: String = ""
    @Published var peakCpuTemperature: Double = 0
    @Published var peakGpuTemperature: Double = 0
    @Published var peakSsdTemperature: Double = 0

    var isMenuVisible = false {
        didSet { updatePollInterval() }
    }

    private var smc: SMCConnection?
    private var timer: Timer?
    private var discoveredSensors: [String: TemperatureSensor] = [:]
    private var activeSensorKeys: Set<String>?
    private var discoveryPollCount: Int = 0
    private let smcQueue = DispatchQueue(label: "com.idevtim.StillAir.smc")
    private var pollInFlight = false

    private enum ThermalZone {
        case cpu, gpu, ssd
    }

    private static let zoneSensorKeys: [ThermalZone: Set<String>] = [
        .cpu: ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b",
               "TCDX", "TCMb", "TCMz", "TCHP", "TC0P", "TC0D"],
        .gpu: ["TPDX", "TPMP", "TPSP", "TG0P", "TG0D"],
        .ssd: ["TH0x", "TH0a", "TH0b"],
    ]

    func startMonitoring() {
        do {
            smc = try SMCConnection()
            smcError = nil
        } catch {
            smcError = error.localizedDescription
            return
        }

        poll()
        schedulePollTimer()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        smc?.close()
        smc = nil
    }

    private var currentPollInterval: TimeInterval {
        isMenuVisible ? 2.0 : 10.0
    }

    private func schedulePollTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentPollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func updatePollInterval() {
        guard timer != nil else { return }
        schedulePollTimer()
    }

    private func poll() {
        guard let smc = smc, !pollInFlight else { return }
        pollInFlight = true

        smcQueue.async { [weak self] in
            guard let self else { return }

            self.discoveryPollCount += 1
            let keysToProbe: [(key: String, label: String)]
            if let activeKeys = self.activeSensorKeys {
                keysToProbe = SMCKey.temperatureKeys.filter { activeKeys.contains($0.key) }
            } else {
                keysToProbe = SMCKey.temperatureKeys
            }

            for (key, label) in keysToProbe {
                if let temp = try? smc.readTemperature(key: key), temp > 0, temp < 150 {
                    self.discoveredSensors[key] = TemperatureSensor(id: key, label: label, temperature: temp)
                }
            }

            if self.activeSensorKeys == nil && self.discoveryPollCount >= 5 && !self.discoveredSensors.isEmpty {
                self.activeSensorKeys = Set(self.discoveredSensors.keys)
            }

            let stableSensors = SMCKey.temperatureKeys.compactMap { key, _ in
                self.discoveredSensors[key]
            }
            let hottest = stableSensors.max { $0.temperature < $1.temperature }
            let peak = hottest?.temperature ?? 0
            let peakLabel = hottest?.label ?? ""

            func zonePeak(_ zone: ThermalZone) -> Double {
                guard let keys = Self.zoneSensorKeys[zone] else { return 0 }
                return keys.compactMap { self.discoveredSensors[$0]?.temperature }.max() ?? 0
            }
            let cpuPeak = zonePeak(.cpu)
            let gpuPeak = zonePeak(.gpu)
            let ssdPeak = zonePeak(.ssd)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                defer { self.pollInFlight = false }

                if self.smcError != nil {
                    self.smcError = nil
                }

                let tempEpsilon = 0.1
                if abs(self.peakTemperature - peak) >= tempEpsilon {
                    self.peakTemperature = peak
                }
                if self.peakTemperatureLabel != peakLabel {
                    self.peakTemperatureLabel = peakLabel
                }
                if abs(self.peakCpuTemperature - cpuPeak) >= tempEpsilon {
                    self.peakCpuTemperature = cpuPeak
                }
                if abs(self.peakGpuTemperature - gpuPeak) >= tempEpsilon {
                    self.peakGpuTemperature = gpuPeak
                }
                if abs(self.peakSsdTemperature - ssdPeak) >= tempEpsilon {
                    self.peakSsdTemperature = ssdPeak
                }
                if self.isMenuVisible, self.sensors != stableSensors {
                    self.sensors = stableSensors
                }
            }
        }
    }
}
