import AVFoundation
import AudioToolbox
import CoreAudio
import Darwin
import Foundation
import Accelerate

/// One Core Audio clock for BlackHole capture and headphone playback.
/// Drift compensation on the private aggregate is what stops Bluetooth crackle.
final class SyncedIO {
    private var aggregateID: AudioDeviceID = 0
    private var procID: AudioDeviceIOProcID?
    private let ioQueue = DispatchQueue(label: "cinema-engine.io", qos: .userInteractive)
    private var running = false
    private let state = RenderState()
    private var pullCapture: HALCapture?
    private var pullPlayback: HALPlayback?

    var peakL: Float { state.peakL }
    var peakR: Float { state.peakR }

    func start(
        blackHole: AudioDeviceInfo,
        playback: AudioDeviceInfo,
        format: AVAudioFormat,
        renderBlock: @escaping AVAudioEngineManualRenderingBlock
    ) throws {
        stop()
        state.format = format
        state.renderBlock = renderBlock
        guard let scratch = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192),
              let inputScratch = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192)
        else {
            throw DeviceManagerError.coreAudio(-1, "IO scratch buffer")
        }
        state.scratch = scratch
        state.inputScratch = inputScratch

        do {
            try startAggregate(blackHole: blackHole, playback: playback, format: format)
        } catch {
            try startPull(blackHole: blackHole, playback: playback, format: format)
        }
    }

    func stop() {
        running = false
        if aggregateID != 0, let procID {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
        }
        procID = nil
        if aggregateID != 0 {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = 0
        }
        pullPlayback?.stop()
        pullPlayback = nil
        pullCapture?.stop()
        pullCapture = nil
        state.renderBlock = nil
        state.scratch = nil
        state.inputScratch = nil
        state.hasPending = false
    }

    func copyInput(into abl: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        state.copyInput(into: abl, frames: frames)
    }

    private func startAggregate(
        blackHole: AudioDeviceInfo,
        playback: AudioDeviceInfo,
        format: AVAudioFormat
    ) throws {
        let uid = "cinema-engine.io.\(UUID().uuidString)"
        let subdevices: [[String: Any]] = [
            [
                kAudioSubDeviceUIDKey as String: blackHole.uid,
                kAudioSubDeviceDriftCompensationKey as String: 1
            ],
            [
                kAudioSubDeviceUIDKey as String: playback.uid,
                kAudioSubDeviceDriftCompensationKey as String: 0
            ]
        ]
        var description: [String: Any] = [
            kAudioAggregateDeviceNameKey as String: "cinema-engine",
            kAudioAggregateDeviceUIDKey as String: uid,
            kAudioAggregateDeviceIsPrivateKey as String: 1,
            kAudioAggregateDeviceIsStackedKey as String: 0,
            kAudioAggregateDeviceClockDeviceKey as String: playback.uid,
            kAudioAggregateDeviceSubDeviceListKey as String: subdevices
        ]
        description[kAudioAggregateDeviceMainSubDeviceKey as String] = playback.uid

        var id = AudioDeviceID()
        let status = AudioHardwareCreateAggregateDevice(description as CFDictionary, &id)
        guard status == noErr, id != 0 else {
            throw DeviceManagerError.coreAudio(status, "creating synced audio device")
        }
        aggregateID = id
        Thread.sleep(forTimeInterval: 0.08)

        DeviceManager.setNominalSampleRate(format.sampleRate, device: id)
        DeviceManager.setPreferredIOBuffer(1024, device: id)
        DeviceManager.setPreferredIOBuffer(1024, device: blackHole.id)
        DeviceManager.setPreferredIOBuffer(1024, device: playback.id)

        let outputs = DeviceManager.streamChannelCounts(device: id, scope: kAudioDevicePropertyScopeOutput)
        state.outputStream = outputs.count > 1 ? 1 : 0

        let capturedState = state
        var newProcID: AudioDeviceIOProcID?
        let procStatus = AudioDeviceCreateIOProcIDWithBlock(&newProcID, id, ioQueue) { _, inputData, _, outputData, _ in
            RenderState.render(input: inputData, output: outputData, state: capturedState)
        }
        guard procStatus == noErr, let newProcID else {
            AudioHardwareDestroyAggregateDevice(id)
            aggregateID = 0
            throw DeviceManagerError.coreAudio(procStatus, "starting synced IO")
        }
        procID = newProcID
        disableExtraStreams(device: id, proc: newProcID, outputStreamCount: outputs.count)

        let startStatus = AudioDeviceStart(id, newProcID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(id, newProcID)
            procID = nil
            AudioHardwareDestroyAggregateDevice(id)
            aggregateID = 0
            throw DeviceManagerError.coreAudio(startStatus, "starting synced device")
        }
        running = true
    }

    private func startPull(
        blackHole: AudioDeviceInfo,
        playback: AudioDeviceInfo,
        format: AVAudioFormat
    ) throws {
        DeviceManager.setPreferredIOBuffer(1024, device: blackHole.id)
        DeviceManager.setPreferredIOBuffer(1024, device: playback.id)

        let capture = HALCapture()
        try capture.start(deviceID: blackHole.id, sampleRate: format.sampleRate, pullMode: true)
        pullCapture = capture

        let capturedState = state
        let playbackUnit = HALPlayback()
        try playbackUnit.start(deviceID: playback.id, format: format) { flags, timestamp, frames, ioData in
            capturedState.pullAndRender(
                capture: capture,
                flags: flags,
                timestamp: timestamp,
                frames: frames,
                ioData: ioData
            )
        }
        pullPlayback = playbackUnit
        running = true
    }

    private func disableExtraStreams(device: AudioDeviceID, proc: AudioDeviceIOProcID, outputStreamCount: Int) {
        let inputCount = DeviceManager.streamChannelCounts(device: device, scope: kAudioDevicePropertyScopeInput).count
        setStreamUsage(device: device, proc: proc, scope: kAudioDevicePropertyScopeInput, count: inputCount) { index in
            index == 0 ? 1 : 0
        }
        setStreamUsage(device: device, proc: proc, scope: kAudioDevicePropertyScopeOutput, count: outputStreamCount) { index in
            index == (outputStreamCount > 1 ? 1 : 0) ? 1 : 0
        }
    }

    private func setStreamUsage(
        device: AudioDeviceID,
        proc: AudioDeviceIOProcID,
        scope: AudioObjectPropertyScope,
        count: Int,
        enabled: (Int) -> UInt32
    ) {
        guard count > 0 else { return }
        let headerSize = MemoryLayout<UnsafeMutableRawPointer>.size + MemoryLayout<UInt32>.size
        let totalSize = headerSize + count * MemoryLayout<UInt32>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: totalSize, alignment: MemoryLayout<UnsafeMutableRawPointer>.alignment)
        defer { raw.deallocate() }
        let procPointer = unsafeBitCast(proc, to: UnsafeMutableRawPointer.self)
        raw.storeBytes(of: procPointer, toByteOffset: 0, as: UnsafeMutableRawPointer.self)
        raw.storeBytes(of: UInt32(count), toByteOffset: MemoryLayout<UnsafeMutableRawPointer>.size, as: UInt32.self)
        let flags = raw.advanced(by: headerSize).bindMemory(to: UInt32.self, capacity: count)
        for index in 0..<count {
            flags[index] = enabled(index)
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyIOProcStreamUsage,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        _ = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(totalSize), raw)
    }
}

private final class RenderState {
    var renderBlock: AVAudioEngineManualRenderingBlock?
    var scratch: AVAudioPCMBuffer?
    var inputScratch: AVAudioPCMBuffer?
    var format: AVAudioFormat?
    var outputStream = 0
    var peakL: Float = 0
    var peakR: Float = 0
    var holdL: Float = 0
    var holdR: Float = 0
    var hasPending = false

    func copyInput(into abl: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        let dest = UnsafeMutableAudioBufferListPointer(abl)
        guard hasPending, let inputScratch, let src = inputScratch.floatChannelData, frames > 0 else {
            for buffer in dest {
                if let data = buffer.mData {
                    let bytes = buffer.mDataByteSize > 0 ? Int(buffer.mDataByteSize) : frames * Int(max(buffer.mNumberChannels, 1)) * MemoryLayout<Float>.size
                    memset(data, 0, bytes)
                }
            }
            return
        }
        let count = min(frames, Int(inputScratch.frameLength))
        let bytes = count * MemoryLayout<Float>.size
        if dest.count >= 2 {
            memcpy(dest[0].mData, src[0], bytes)
            memcpy(dest[1].mData, src[min(1, Int(inputScratch.format.channelCount) - 1)], bytes)
            return
        }
        if dest.count == 1, let data = dest[0].mData?.assumingMemoryBound(to: Float.self) {
            if dest[0].mNumberChannels >= 2 {
                let right = inputScratch.format.channelCount > 1 ? src[1] : src[0]
                for i in 0..<count {
                    data[i * 2] = src[0][i]
                    data[i * 2 + 1] = right[i]
                }
            } else {
                memcpy(data, src[0], bytes)
            }
        }
    }

    static func render(
        input: UnsafePointer<AudioBufferList>,
        output: UnsafeMutablePointer<AudioBufferList>,
        state: RenderState
    ) {
        let inBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outBuffers = UnsafeMutableAudioBufferListPointer(output)
        guard let scratch = state.scratch, let inputScratch = state.inputScratch, let renderBlock = state.renderBlock else {
            silence(outBuffers)
            return
        }

        let frames = frameCount(inBuffers) ?? frameCount(outBuffers) ?? 0
        guard frames > 0, frames <= Int(scratch.frameCapacity) else {
            silence(outBuffers)
            return
        }

        inputScratch.frameLength = AVAudioFrameCount(frames)
        fillScratch(inputScratch, from: inBuffers, frames: frames)
        state.hasPending = true

        scratch.frameLength = AVAudioFrameCount(frames)
        let abl = UnsafeMutableAudioBufferListPointer(scratch.mutableAudioBufferList)
        for i in 0..<abl.count {
            abl[i].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
        }

        let status = renderBlock(AVAudioFrameCount(frames), scratch.mutableAudioBufferList, nil)
        state.hasPending = false
        switch status {
        case .success, .insufficientDataFromInputNode:
            writeOutput(outBuffers, from: scratch, frames: frames, stream: state.outputStream, state: state)
        default:
            holdOutput(outBuffers, frames: frames, stream: state.outputStream, state: state)
        }
    }

    func pullAndRender(
        capture: HALCapture,
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>
    ) {
        guard let scratch, let inputScratch, let renderBlock, frames > 0, frames <= scratch.frameCapacity else {
            SyncedIOSilence.silence(UnsafeMutableAudioBufferListPointer(ioData))
            return
        }
        inputScratch.frameLength = frames
        let inABL = UnsafeMutableAudioBufferListPointer(inputScratch.mutableAudioBufferList)
        for i in 0..<inABL.count {
            inABL[i].mDataByteSize = frames * UInt32(MemoryLayout<Float>.size)
        }
        let pullStatus = capture.pull(flags: flags, timestamp: timestamp, frames: frames, into: inputScratch.mutableAudioBufferList)
        if pullStatus != noErr {
            holdOutput(UnsafeMutableAudioBufferListPointer(ioData), frames: Int(frames), stream: 0, state: self)
            return
        }
        hasPending = true
        scratch.frameLength = frames
        let status = renderBlock(frames, scratch.mutableAudioBufferList, nil)
        hasPending = false
        switch status {
        case .success, .insufficientDataFromInputNode:
            copyEngine(scratch, to: ioData, frames: Int(frames))
            updatePeaks(scratch, frames: Int(frames))
        default:
            holdOutput(UnsafeMutableAudioBufferListPointer(ioData), frames: Int(frames), stream: 0, state: self)
        }
    }

    private func copyEngine(_ buffer: AVAudioPCMBuffer, to ioData: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        guard let src = buffer.floatChannelData else { return }
        let dest = UnsafeMutableAudioBufferListPointer(ioData)
        if dest.count >= 2 {
            memcpy(dest[0].mData, src[0], frames * MemoryLayout<Float>.size)
            memcpy(dest[1].mData, src[min(1, Int(buffer.format.channelCount) - 1)], frames * MemoryLayout<Float>.size)
            dest[0].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            dest[1].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
            return
        }
        guard dest.count == 1, let data = dest[0].mData?.assumingMemoryBound(to: Float.self) else { return }
        if dest[0].mNumberChannels >= 2 {
            let right = buffer.format.channelCount > 1 ? src[1] : src[0]
            for i in 0..<frames {
                data[i * 2] = src[0][i]
                data[i * 2 + 1] = right[i]
            }
            dest[0].mDataByteSize = UInt32(frames * 2 * MemoryLayout<Float>.size)
        } else {
            memcpy(data, src[0], frames * MemoryLayout<Float>.size)
            dest[0].mDataByteSize = UInt32(frames * MemoryLayout<Float>.size)
        }
    }

    private func updatePeaks(_ buffer: AVAudioPCMBuffer, frames: Int) {
        guard let src = buffer.floatChannelData, frames > 0 else { return }
        var l: Float = 0
        var r: Float = 0
        vDSP_maxmgv(src[0], 1, &l, vDSP_Length(frames))
        if buffer.format.channelCount > 1 {
            vDSP_maxmgv(src[1], 1, &r, vDSP_Length(frames))
        } else {
            r = l
        }
        peakL = max(peakL * 0.82, l)
        peakR = max(peakR * 0.82, r)
        holdL = src[0][frames - 1]
        holdR = buffer.format.channelCount > 1 ? src[1][frames - 1] : holdL
    }
}

private enum SyncedIOSilence {
    static func silence(_ buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            if let data = buffer.mData, buffer.mDataByteSize > 0 {
                memset(data, 0, Int(buffer.mDataByteSize))
            }
        }
    }
}

private func silence(_ buffers: UnsafeMutableAudioBufferListPointer) {
    SyncedIOSilence.silence(buffers)
}

private func frameCount(_ buffers: UnsafeMutableAudioBufferListPointer) -> Int? {
    guard let first = buffers.first, first.mNumberChannels > 0, first.mDataByteSize > 0 else {
        return nil
    }
    return Int(first.mDataByteSize) / (MemoryLayout<Float>.size * Int(first.mNumberChannels))
}

private func fillScratch(_ scratch: AVAudioPCMBuffer, from inputs: UnsafeMutableAudioBufferListPointer, frames: Int) {
    guard let dst = scratch.floatChannelData else { return }
    guard let buffer = inputs.first, let data = buffer.mData else {
        memset(dst[0], 0, frames * MemoryLayout<Float>.size)
        if scratch.format.channelCount > 1 {
            memset(dst[1], 0, frames * MemoryLayout<Float>.size)
        }
        return
    }
    let src = data.assumingMemoryBound(to: Float.self)
    let channels = Int(max(buffer.mNumberChannels, 1))
    if channels == 1 {
        memcpy(dst[0], src, frames * MemoryLayout<Float>.size)
        if scratch.format.channelCount > 1 {
            memcpy(dst[1], src, frames * MemoryLayout<Float>.size)
        }
        return
    }
    for i in 0..<frames {
        dst[0][i] = src[i * channels]
        if scratch.format.channelCount > 1 {
            dst[1][i] = src[i * channels + 1]
        }
    }
}

private func writeOutput(
    _ outputs: UnsafeMutableAudioBufferListPointer,
    from scratch: AVAudioPCMBuffer,
    frames: Int,
    stream: Int,
    state: RenderState
) {
    guard let src = scratch.floatChannelData else {
        silence(outputs)
        return
    }
    for (index, buffer) in outputs.enumerated() {
        guard let data = buffer.mData else { continue }
        if index != stream {
            memset(data, 0, Int(buffer.mDataByteSize))
            continue
        }
        let dst = data.assumingMemoryBound(to: Float.self)
        let channels = Int(max(buffer.mNumberChannels, 1))
        let right = scratch.format.channelCount > 1 ? src[1] : src[0]
        if channels == 1 {
            memcpy(dst, src[0], frames * MemoryLayout<Float>.size)
        } else {
            for i in 0..<frames {
                dst[i * channels] = src[0][i]
                dst[i * channels + 1] = right[i]
            }
        }
        state.peakL = max(state.peakL * 0.82, abs(src[0][frames - 1]))
        state.peakR = max(state.peakR * 0.82, abs(right[frames - 1]))
        var l: Float = 0
        var r: Float = 0
        vDSP_maxmgv(src[0], 1, &l, vDSP_Length(frames))
        vDSP_maxmgv(right, 1, &r, vDSP_Length(frames))
        state.peakL = max(state.peakL, l)
        state.peakR = max(state.peakR, r)
        state.holdL = src[0][frames - 1]
        state.holdR = right[frames - 1]
    }
}

private func holdOutput(
    _ outputs: UnsafeMutableAudioBufferListPointer,
    frames: Int,
    stream: Int,
    state: RenderState
) {
    for (index, buffer) in outputs.enumerated() {
        guard let data = buffer.mData else { continue }
        if index != stream {
            memset(data, 0, Int(buffer.mDataByteSize))
            continue
        }
        let dst = data.assumingMemoryBound(to: Float.self)
        let channels = Int(max(buffer.mNumberChannels, 1))
        for i in 0..<frames {
            if channels == 1 {
                dst[i] = state.holdL
            } else {
                dst[i * channels] = state.holdL
                dst[i * channels + 1] = state.holdR
            }
        }
    }
}
