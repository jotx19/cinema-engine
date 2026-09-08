import Foundation
import CoreAudio
import AudioToolbox
import AVFoundation

public struct AudioDeviceInfo: Equatable, Sendable {
    public var id: AudioDeviceID
    public var uid: String
    public var name: String
    public var isInput: Bool
    public var isOutput: Bool
    public var inputChannels: Int
    public var outputChannels: Int
    public var sampleRate: Double

    public var kind: String {
        switch (isInput, isOutput) {
        case (true, true): return "input/output"
        case (true, false): return "input"
        case (false, true): return "output"
        default: return "unknown"
        }
    }
}

public enum DeviceManagerError: Error, CustomStringConvertible {
    case notFound(String)
    case coreAudio(OSStatus, String)
    case noAudioUnit

    public var description: String {
        switch self {
        case .notFound(let query):
            return "No audio device matching '\(query)'."
        case .coreAudio(let status, let message):
            return "CoreAudio error \(status): \(message)"
        case .noAudioUnit:
            return "Audio unit is not available on this node."
        }
    }
}

public enum DeviceManager {
    public static func listDevices() throws -> [AudioDeviceInfo] {
        let ids = try allDeviceIDs()
        return try ids.compactMap { try info(for: $0) }
    }

    public static func find(query: String, role: DeviceRole) throws -> AudioDeviceInfo {
        let devices = try listDevices().filter { device in
            switch role {
            case .input: return device.isInput
            case .output: return device.isOutput
            }
        }

        let needle = query.lowercased()
        if let exactUID = devices.first(where: { $0.uid.lowercased() == needle }) {
            return exactUID
        }
        if let exactName = devices.first(where: { $0.name.lowercased() == needle }) {
            return exactName
        }
        if let partial = devices.first(where: { $0.name.lowercased().contains(needle) }) {
            return partial
        }
        throw DeviceManagerError.notFound(query)
    }

    public static func setEngineDevices(
        engine: AVAudioEngine,
        input: AudioDeviceInfo?,
        output: AudioDeviceInfo?,
        preferredBufferFrames: UInt32 = 256
    ) throws {
        _ = engine.outputNode

        if let output {
            try setCurrentDevice(output.id, on: engine.outputNode, label: "output '\(output.name)'")
            try? setBufferFrameSize(preferredBufferFrames, device: output.id)
        }
        if let input {
            try? setBufferFrameSize(preferredBufferFrames, device: input.id)
        }
    }

    public static func refresh(_ device: AudioDeviceInfo, role: DeviceRole) -> AudioDeviceInfo {
        (try? find(query: device.uid, role: role))
            ?? (try? find(query: device.name, role: role))
            ?? device
    }

    public static func setPreferredIOBuffer(_ frames: UInt32, device: AudioDeviceID) {
        try? setBufferFrameSize(frames, device: device)
    }

    public static func bufferFrameSize(device: AudioDeviceID) -> UInt32 {
        var size: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, &size)
        return status == noErr ? size : 0
    }

    public static func formattedList() throws -> String {
        let devices = try listDevices()
        let inputs = devices.filter(\.isInput)
        let outputs = devices.filter(\.isOutput)
        var lines: [String] = []

        lines.append("INPUT DEVICES")
        if inputs.isEmpty {
            lines.append("  (none)")
        } else {
            for (index, device) in inputs.enumerated() {
                lines.append(contentsOf: formatDevice(device, index: index))
            }
        }

        lines.append("")
        lines.append("OUTPUT DEVICES")
        if outputs.isEmpty {
            lines.append("  (none)")
        } else {
            for (index, device) in outputs.enumerated() {
                lines.append(contentsOf: formatDevice(device, index: index))
            }
        }
        return lines.joined(separator: "\n")
    }

    public enum DeviceRole {
        case input
        case output
    }

    public static func isVirtualLoopback(_ device: AudioDeviceInfo) -> Bool {
        let name = device.name.lowercased()
        return name.contains("blackhole")
            || name.contains("soundflower")
            || name.contains("loopback")
    }

    public static func isAuto(_ query: String) -> Bool {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return value.isEmpty || value == "auto"
    }

    public static func blackHole(role: DeviceRole) throws -> AudioDeviceInfo {
        let devices = try listDevices()
        let matches = devices.filter { $0.name.localizedCaseInsensitiveContains("blackhole") }
        switch role {
        case .input:
            if let device = matches.first(where: \.isInput) { return device }
        case .output:
            if let device = matches.first(where: \.isOutput) { return device }
        }
        throw DeviceManagerError.notFound("BlackHole 2ch")
    }

    public static func resolveInput(query: String) throws -> AudioDeviceInfo {
        if isAuto(query) {
            return try blackHole(role: .input)
        }
        return try find(query: query, role: .input)
    }

    public static func resolveOutput(query: String, excluding excluded: AudioDeviceInfo? = nil) throws -> AudioDeviceInfo {
        if !isAuto(query),
           let found = try? find(query: query, role: .output),
           found.id != excluded?.id
        {
            return found
        }
        if let current = try? defaultOutputDevice(),
           !isVirtualLoopback(current),
           current.id != excluded?.id
        {
            return current
        }
        if let saved = RoutingSnapshot.load() {
            if let device = try? find(query: saved.previousOutputUID, role: .output), device.id != excluded?.id {
                return device
            }
            if let device = try? find(query: saved.previousOutputName, role: .output), device.id != excluded?.id {
                return device
            }
        }
        return try preferredPlaybackDevice(excluding: excluded)
    }

    public static func preferredPlaybackDevice(excluding excluded: AudioDeviceInfo? = nil) throws -> AudioDeviceInfo {
        let outputs = try listDevices().filter { device in
            device.isOutput
                && device.id != excluded?.id
                && !isVirtualLoopback(device)
        }
        guard let best = outputs.max(by: { playbackScore($0) < playbackScore($1) }) else {
            throw DeviceManagerError.notFound("playback device")
        }
        return best
    }

    public static func defaultOutputDevice() throws -> AudioDeviceInfo {
        try info(forDefault: kAudioHardwarePropertyDefaultOutputDevice)
    }

    public static func defaultInputDevice() throws -> AudioDeviceInfo {
        try info(forDefault: kAudioHardwarePropertyDefaultInputDevice)
    }

    public static func setDefaultOutputDevice(_ device: AudioDeviceInfo) throws {
        try setDefaultDevice(device, selector: kAudioHardwarePropertyDefaultOutputDevice, label: "default output")
    }

    public static func setDefaultInputDevice(_ device: AudioDeviceInfo) throws {
        try setDefaultDevice(device, selector: kAudioHardwarePropertyDefaultInputDevice, label: "default input")
    }

    private static func setDefaultDevice(
        _ device: AudioDeviceInfo,
        selector: AudioObjectPropertySelector,
        label: String
    ) throws {
        var id = device.id
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &id
        )
        try check(status, "setting \(label)")
    }

    private static func playbackScore(_ device: AudioDeviceInfo) -> Int {
        let name = device.name.lowercased()
        if name.contains("airpods") { return 100 }
        if name.contains("headphone") { return 90 }
        if name.contains("headset") { return 80 }
        if device.uid == "BuiltInSpeakerDevice" || name.contains("macbook") { return 50 }
        if name.contains("speaker") { return 40 }
        if name.contains("multi-output") || name.contains("aggregate") { return 5 }
        return 25
    }

    private static func info(forDefault selector: AudioObjectPropertySelector) throws -> AudioDeviceInfo {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize,
            &deviceID
        )
        try check(status, "reading default device")
        guard let device = try info(for: deviceID) else {
            throw DeviceManagerError.notFound("default device")
        }
        return device
    }

    private static func formatDevice(_ device: AudioDeviceInfo, index: Int) -> [String] {
        [
            "  [\(index)] \(device.name)",
            "      uid: \(device.uid)  id: \(device.id)",
            "      \(device.kind), in \(device.inputChannels) ch / out \(device.outputChannels) ch, \(Int(device.sampleRate)) Hz"
        ]
    }

    private static func allDeviceIDs() throws -> [AudioDeviceID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize)
        try check(status, "getting device list size")
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &ids)
        try check(status, "getting device list")
        return ids
    }

    public static func device(id: AudioDeviceID) -> AudioDeviceInfo? {
        try? info(for: id)
    }

    public static func streamChannelCounts(device: AudioDeviceID, scope: AudioObjectPropertyScope) -> [Int] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return []
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, raw) == noErr else {
            return []
        }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.map { Int($0.mNumberChannels) }
    }

    private static func info(for id: AudioDeviceID) throws -> AudioDeviceInfo? {
        let name = (try? stringProperty(id, kAudioDevicePropertyDeviceNameCFString)) ?? "Unknown"
        let uid = (try? stringProperty(id, kAudioDevicePropertyDeviceUID)) ?? "\(id)"
        let inputChannels = channelCount(id, scope: kAudioDevicePropertyScopeInput)
        let outputChannels = channelCount(id, scope: kAudioDevicePropertyScopeOutput)
        guard inputChannels > 0 || outputChannels > 0 else { return nil }
        return AudioDeviceInfo(
            id: id,
            uid: uid,
            name: name,
            isInput: inputChannels > 0,
            isOutput: outputChannels > 0,
            inputChannels: inputChannels,
            outputChannels: outputChannels,
            sampleRate: sampleRate(id)
        )
    }

    private static func stringProperty(_ id: AudioDeviceID, _ selector: AudioObjectPropertySelector) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize)
        try check(status, "property size")
        var cfString: Unmanaged<CFString>?
        status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &cfString)
        try check(status, "property data")
        guard let cfString else { return "" }
        return cfString.takeUnretainedValue() as String
    }

    private static func channelCount(_ id: AudioDeviceID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return 0
        }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(dataSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, raw) == noErr else {
            return 0
        }
        let list = raw.assumingMemoryBound(to: AudioBufferList.self)
        let buffers = UnsafeMutableAudioBufferListPointer(list)
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func sampleRate(_ id: AudioDeviceID) -> Double {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var rate: Float64 = 0
        var dataSize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &rate)
        return status == noErr ? rate : 0
    }

    public static func setNominalSampleRate(_ rate: Double, device: AudioDeviceID) {
        guard rate > 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyNominalSampleRate,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = Float64(rate)
        _ = AudioObjectSetPropertyData(
            device,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float64>.size),
            &value
        )
    }

    /// Bluetooth headphones often sit at volume 0 while macOS volume keys
    /// control BlackHole (the default output). Unmute and raise if silent.
    public static func preparePlayback(_ device: AudioDeviceInfo) {
        setMute(false, device: device.id)
        let current = volume(device: device.id)
        if current >= 0, current < 0.08 {
            setVolume(0.75, device: device.id)
        }
    }

    public static func volume(device: AudioDeviceID) -> Float {
        if let master = volumeScalar(device: device, element: kAudioObjectPropertyElementMain) {
            return master
        }
        let left = volumeScalar(device: device, element: 1) ?? 0
        let right = volumeScalar(device: device, element: 2) ?? left
        if left == 0 && right == 0 && volumeScalar(device: device, element: 1) == nil {
            return -1
        }
        return max(left, right)
    }

    public static func setVolume(_ value: Float, device: AudioDeviceID) {
        let clamped = min(1, max(0, value))
        if !setVolumeScalar(clamped, device: device, element: kAudioObjectPropertyElementMain) {
            setVolumeScalar(clamped, device: device, element: 1)
            setVolumeScalar(clamped, device: device, element: 2)
        }
        setVirtualMasterVolume(clamped, device: device)
    }

    public static func setMute(_ muted: Bool, device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0
        if AudioObjectSetPropertyData(
            device,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        ) != noErr {
            address.mElement = 1
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
            address.mElement = 2
            AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value)
        }
    }

    private static func volumeScalar(device: AudioDeviceID, element: AudioObjectPropertyElement) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var value: Float32 = 0
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, &value)
        return status == noErr ? value : nil
    }

    @discardableResult
    private static func setVolumeScalar(_ value: Float, device: AudioDeviceID, element: AudioObjectPropertyElement) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
        var scalar = Float32(value)
        return AudioObjectSetPropertyData(
            device,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &scalar
        ) == noErr
    }

    private static func setVirtualMasterVolume(_ value: Float, device: AudioDeviceID) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var volume = Float32(value)
        _ = AudioObjectSetPropertyData(
            device,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<Float32>.size),
            &volume
        )
    }

    private static func setCurrentDevice(_ deviceID: AudioDeviceID, on node: AVAudioIONode, label: String) throws {
        guard let audioUnit = node.audioUnit else {
            throw DeviceManagerError.noAudioUnit
        }
        var id = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &id,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        try check(status, "setting \(label)")
    }

    private static func setBufferFrameSize(_ preferred: UInt32, device: AudioDeviceID) throws {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSize,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = clampBufferSize(preferred, device: device)
        let status = AudioObjectSetPropertyData(
            device,
            &address,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &value
        )
        if status != noErr && status != kAudioHardwareUnknownPropertyError {
            try check(status, "setting buffer frame size")
        }
    }

    private static func clampBufferSize(_ preferred: UInt32, device: AudioDeviceID) -> UInt32 {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyBufferFrameSizeRange,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var range = AudioValueRange()
        var dataSize = UInt32(MemoryLayout<AudioValueRange>.size)
        let status = AudioObjectGetPropertyData(device, &address, 0, nil, &dataSize, &range)
        guard status == noErr else { return preferred }
        let minSize = UInt32(range.mMinimum)
        let maxSize = UInt32(range.mMaximum)
        return min(max(preferred, minSize), maxSize)
    }

    private static func check(_ status: OSStatus, _ message: String) throws {
        if status != noErr {
            throw DeviceManagerError.coreAudio(status, message)
        }
    }
}
