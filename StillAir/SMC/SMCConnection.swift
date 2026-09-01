import Foundation
import IOKit

final class SMCConnection {
    private var connection: io_connect_t = 0
    private var isOpen = false
    /// Cache key info (dataSize) per fourCharCode — avoids redundant getKeyInfo IOKit calls
    private var keyInfoCache: [UInt32: UInt32] = [:]

    init() throws {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSMC")
        )
        guard service != 0 else {
            throw SMCError.driverNotFound
        }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        IOObjectRelease(service)

        guard result == kIOReturnSuccess else {
            throw SMCError.failedToOpen
        }
        isOpen = true
    }

    deinit {
        close()
    }

    func close() {
        if isOpen {
            IOServiceClose(connection)
            isOpen = false
        }
    }

    // MARK: - Low-level Read

    func readKey(_ key: String) throws -> SMCParamStruct {
        var input = SMCParamStruct()
        let fcc = fourCharCode(key)
        input.key = fcc

        // Check cache for dataSize to skip the getKeyInfo IOKit call
        let dataSize: UInt32
        if let cached = keyInfoCache[fcc] {
            dataSize = cached
        } else {
            input.data8 = SMCSelector.getKeyInfo.rawValue
            var infoOutput = SMCParamStruct()
            let result = callSMC(&input, output: &infoOutput)
            guard result == kIOReturnSuccess else {
                throw SMCError.keyNotFound(key)
            }
            dataSize = infoOutput.keyInfo.dataSize
            keyInfoCache[fcc] = dataSize
        }

        // Read the actual value
        input.keyInfo.dataSize = dataSize
        input.data8 = SMCSelector.readKey.rawValue

        var output = SMCParamStruct()
        let result = callSMC(&input, output: &output)
        guard result == kIOReturnSuccess else {
            throw SMCError.readFailed(result)
        }
        if output.result == 132 {
            throw SMCError.keyNotFound(key)
        }
        // Preserve the data size for callers that need it
        output.keyInfo.dataSize = dataSize
        return output
    }

    // MARK: - Temperature Reads

    func readTemperature(key: String) throws -> Double {
        let output = try readKey(key)
        // Apple Silicon: 4-byte little-endian float; Intel: 2-byte sp78
        if output.keyInfo.dataSize >= 4 {
            let val = decodeFloat32(output.bytes.0, output.bytes.1, output.bytes.2, output.bytes.3)
            if val > -40 && val < 200 { return val }
        }
        return decodeSP78(output.bytes.0, output.bytes.1)
    }

    // MARK: - Key Enumeration

    /// Get total number of SMC keys
    func getKeyCount() throws -> Int {
        let output = try readKey("#KEY")
        let count = (UInt32(output.bytes.0) << 24) | (UInt32(output.bytes.1) << 16) |
                    (UInt32(output.bytes.2) << 8) | UInt32(output.bytes.3)
        return Int(count)
    }

    /// Get the key at a given index
    func getKeyAtIndex(_ index: Int) throws -> String {
        var input = SMCParamStruct()
        input.data32 = UInt32(index)
        input.data8 = SMCSelector.getKeyFromIndex.rawValue

        var output = SMCParamStruct()
        let result = callSMC(&input, output: &output)
        guard result == kIOReturnSuccess else {
            throw SMCError.readFailed(result)
        }
        return fourCharCodeToString(output.key)
    }

    // MARK: - Internal

    private func callSMC(_ input: inout SMCParamStruct, output: inout SMCParamStruct) -> kern_return_t {
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        var outputSize = MemoryLayout<SMCParamStruct>.stride

        return IOConnectCallStructMethod(
            connection,
            UInt32(2), // kSMCHandleYPCEvent
            &input,
            inputSize,
            &output,
            &outputSize
        )
    }
}
