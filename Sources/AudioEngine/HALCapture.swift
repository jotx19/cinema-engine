import AVFoundation
import AudioToolbox
import CoreAudio
import Darwin
import Foundation

/// Captures a CoreAudio input device (BlackHole) with AUHAL, independent of AVAudioEngine.inputNode.
final class HALCapture {
    private var unit: AudioUnit?
    private let ring: AdaptiveRing
    private var bufferList: UnsafeMutableAudioBufferListPointer
    private var rawBuffer: UnsafeMutableRawPointer
    private let channelCount = 2
    private let maxFrames = 8192

    var available: Double { ring.availableFrames }

    init() {
        ring = AdaptiveRing(frames: 24_576, target: 3_072)
        let listSize = AudioBufferList.sizeInBytes(maximumBuffers: channelCount)
        rawBuffer = UnsafeMutableRawPointer.allocate(byteCount: listSize, alignment: 16)
        bufferList = UnsafeMutableAudioBufferListPointer(rawBuffer.bindMemory(to: AudioBufferList.self, capacity: 1))
        bufferList.count = channelCount
        for i in 0..<channelCount {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: maxFrames)
            data.initialize(repeating: 0, count: maxFrames)
            bufferList[i].mNumberChannels = 1
            bufferList[i].mDataByteSize = UInt32(maxFrames * MemoryLayout<Float>.size)
            bufferList[i].mData = UnsafeMutableRawPointer(data)
        }
    }

    deinit {
        stop()
        for i in 0..<bufferList.count {
            bufferList[i].mData?.assumingMemoryBound(to: Float.self).deallocate()
        }
        rawBuffer.deallocate()
    }

    func start(deviceID: AudioDeviceID, sampleRate: Double, pullMode: Bool = false) throws {
        stop()

        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw DeviceManagerError.coreAudio(-1, "HAL output component missing")
        }
        var instance: AudioUnit?
        try check(AudioComponentInstanceNew(component, &instance), "creating HAL unit")
        guard let instance else {
            throw DeviceManagerError.noAudioUnit
        }

        var enable: UInt32 = 1
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enable, size(enable)),
            "enable HAL input"
        )
        var disable: UInt32 = 0
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &disable, size(disable)),
            "disable HAL output"
        )

        var id = deviceID
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, size(id)),
            "HAL current device"
        )
        DeviceManager.setPreferredIOBuffer(1024, device: deviceID)
        DeviceManager.setNominalSampleRate(sampleRate, device: deviceID)

        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagsNativeEndian,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        try check(
            AudioUnitSetProperty(instance, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, size(asbd)),
            "HAL stream format"
        )

        var maxFramesPerSlice = UInt32(maxFrames)
        AudioUnitSetProperty(
            instance,
            kAudioUnitProperty_MaximumFramesPerSlice,
            kAudioUnitScope_Global,
            0,
            &maxFramesPerSlice,
            size(maxFramesPerSlice)
        )

        if !pullMode {
            var callback = AURenderCallbackStruct(
                inputProc: halInputCallback,
                inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
            )
            try check(
                AudioUnitSetProperty(instance, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callback, size(callback)),
                "HAL input callback"
            )
        }

        try check(AudioUnitInitialize(instance), "HAL initialize")
        try check(AudioOutputUnitStart(instance), "HAL start")
        unit = instance
    }

    func pull(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frames: UInt32,
        into abl: UnsafeMutablePointer<AudioBufferList>
    ) -> OSStatus {
        guard let unit, frames > 0 else { return noErr }
        return AudioUnitRender(unit, flags, timestamp, 1, frames, abl)
    }

    func stop() {
        guard let unit else { return }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        self.unit = nil
        ring.reset()
    }

    func read(into abl: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        ring.read(into: UnsafeMutableAudioBufferListPointer(abl), frames: frames)
    }

    func prefill() {
        ring.prefillToTarget()
    }

    func waitForFill(timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while ring.availableFrames < ring.target && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.004)
        }
        ring.prefillToTarget()
    }

    fileprivate func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        bus: UInt32,
        frames: UInt32
    ) -> OSStatus {
        guard let unit, frames > 0, frames <= UInt32(maxFrames) else { return noErr }
        for i in 0..<bufferList.count {
            bufferList[i].mDataByteSize = frames * UInt32(MemoryLayout<Float>.size)
        }
        let status = AudioUnitRender(
            unit,
            flags,
            timestamp,
            bus,
            frames,
            rawBuffer.assumingMemoryBound(to: AudioBufferList.self)
        )
        guard status == noErr else { return status }
        ring.write(from: bufferList, frames: Int(frames))
        return noErr
    }

    private func size<T>(_ value: T) -> UInt32 {
        UInt32(MemoryLayout.size(ofValue: value))
    }

    private func check(_ status: OSStatus, _ message: String) throws {
        if status != noErr {
            throw DeviceManagerError.coreAudio(status, message)
        }
    }
}

private func halInputCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    let capture = Unmanaged<HALCapture>.fromOpaque(inRefCon).takeUnretainedValue()
    return capture.render(flags: ioActionFlags, timestamp: inTimeStamp, bus: inBusNumber, frames: inNumberFrames)
}

final class AdaptiveRing {
    let target: Double
    private let left: UnsafeMutablePointer<Float>
    private let right: UnsafeMutablePointer<Float>
    private let capacity: Int
    private var writeIndex = 0
    private var readIndex: Double = 0
    private var queued: Double = 0
    private var lastL: Float = 0
    private var lastR: Float = 0
    private let lock = NSLock()

    init(frames: Int, target: Double) {
        capacity = max(frames, 4096)
        self.target = min(target, Double(capacity) / 3)
        left = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        right = UnsafeMutablePointer<Float>.allocate(capacity: capacity)
        left.initialize(repeating: 0, count: capacity)
        right.initialize(repeating: 0, count: capacity)
    }

    deinit {
        left.deallocate()
        right.deallocate()
    }

    var availableFrames: Double {
        lock.lock()
        defer { lock.unlock() }
        return queued
    }

    func reset() {
        lock.lock()
        writeIndex = 0
        readIndex = 0
        queued = 0
        lastL = 0
        lastR = 0
        lock.unlock()
    }

    func prefillToTarget() {
        lock.lock()
        if queued < target {
            let extra = Int((target - queued).rounded(.up))
            writeIndex = (writeIndex + extra) % capacity
            queued += Double(extra)
        }
        lock.unlock()
    }

    func write(from abl: UnsafeMutableAudioBufferListPointer, frames: Int) {
        guard frames > 0 else { return }
        let srcL = abl.count > 0 ? abl[0].mData?.assumingMemoryBound(to: Float.self) : nil
        let srcR = abl.count > 1 ? abl[1].mData?.assumingMemoryBound(to: Float.self) : srcL
        let interleaved = abl.count == 1 && (abl[0].mNumberChannels >= 2)

        lock.lock()
        var remaining = frames
        var offset = 0
        while remaining > 0 {
            let chunk = min(remaining, capacity - writeIndex)
            if interleaved, let src = srcL {
                for i in 0..<chunk {
                    left[writeIndex + i] = src[(offset + i) * 2]
                    right[writeIndex + i] = src[(offset + i) * 2 + 1]
                }
            } else {
                if let srcL {
                    memcpy(left.advanced(by: writeIndex), srcL.advanced(by: offset), chunk * MemoryLayout<Float>.size)
                }
                if let srcR {
                    memcpy(right.advanced(by: writeIndex), srcR.advanced(by: offset), chunk * MemoryLayout<Float>.size)
                } else if let srcL {
                    memcpy(right.advanced(by: writeIndex), srcL.advanced(by: offset), chunk * MemoryLayout<Float>.size)
                }
            }
            writeIndex = (writeIndex + chunk) % capacity
            remaining -= chunk
            offset += chunk
        }

        queued += Double(frames)
        if queued > Double(capacity - 64) {
            let drop = queued - target
            readIndex += drop
            queued = target
            wrapReadLocked()
        }
        lock.unlock()
    }

    func read(into abl: UnsafeMutableAudioBufferListPointer, frames: Int) {
        guard frames > 0 else { return }
        let dest = destination(abl)

        lock.lock()
        var ratio = 1.0
        if queued > 8 {
            let error = (queued - target) / max(target, 1)
            ratio = min(1.006, max(0.994, 1.0 + error * 0.006))
        }

        let canPlay = queued > 2
        for i in 0..<frames {
            let sample = interpolateLocked(ratio: canPlay ? ratio : 0)
            dest.set(i, left: sample.0, right: sample.1)
        }
        lock.unlock()
    }

    private func interpolateLocked(ratio: Double) -> (Float, Float) {
        guard ratio > 0, queued > 2 else {
            return (lastL, lastR)
        }
        let i0 = ((Int(readIndex) % capacity) + capacity) % capacity
        let i1 = (i0 + 1) % capacity
        let frac = Float(readIndex - floor(readIndex))
        lastL = left[i0] + (left[i1] - left[i0]) * frac
        lastR = right[i0] + (right[i1] - right[i0]) * frac
        readIndex += ratio
        queued -= ratio
        if queued < 0 { queued = 0 }
        wrapReadLocked()
        return (lastL, lastR)
    }

    private func wrapReadLocked() {
        let cap = Double(capacity)
        while readIndex >= cap { readIndex -= cap }
        while readIndex < 0 { readIndex += cap }
    }

    private func destination(_ abl: UnsafeMutableAudioBufferListPointer) -> RingDestination {
        if abl.count >= 2 {
            return .planar(
                abl[0].mData?.assumingMemoryBound(to: Float.self),
                abl[1].mData?.assumingMemoryBound(to: Float.self)
            )
        }
        if abl.count == 1, let data = abl[0].mData?.assumingMemoryBound(to: Float.self) {
            if abl[0].mNumberChannels >= 2 {
                return .interleaved(data)
            }
            return .planar(data, nil)
        }
        return .planar(nil, nil)
    }
}

private enum RingDestination {
    case planar(UnsafeMutablePointer<Float>?, UnsafeMutablePointer<Float>?)
    case interleaved(UnsafeMutablePointer<Float>)

    func set(_ i: Int, left: Float, right: Float) {
        switch self {
        case .planar(let l, let r):
            l?[i] = left
            r?[i] = right
        case .interleaved(let data):
            data[i * 2] = left
            data[i * 2 + 1] = right
        }
    }
}
