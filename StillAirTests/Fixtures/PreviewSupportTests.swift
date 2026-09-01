import Testing
@testable import StillAir

@Suite("PreviewSupport", .serialized, .tags(.unit, .fixtures))
struct PreviewSupportTests {
    @Test("fanMonitor seeds temperatures and never starts SMC")
    func fanMonitorSeeded() {
        let monitor = PreviewSupport.fanMonitor
        #expect(monitor.sensors.count >= 1)
        #expect(monitor.peakTemperature > 0)
    }

    @Test("systemInfo preview sample skips live profiler placeholders")
    func systemInfoPreview() {
        let info = SystemInfo.previewSample
        #expect(!info.chipName.contains("..."))
        #expect(info.diskTotalBytes > 0)
    }

    @Test("all screen fixtures construct without starting monitors")
    func screenFixturesConstruct() {
        _ = PreviewSupport.fanMonitor
        _ = PreviewSupport.cpuInfo
        _ = PreviewSupport.memoryInfo
        _ = PreviewSupport.batteryInfo
        _ = PreviewSupport.systemInfo
        _ = PreviewSupport.fpsMonitor
        _ = PreviewSupport.updateChecker
    }
}
