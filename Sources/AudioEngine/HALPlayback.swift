import AVFoundation
import AudioToolbox
import CoreAudio
import Darwin
import Foundation

/// Plays to a specific CoreAudio output device (AirPods, speakers) with AUHAL,
/// so AVAudioEngine never has to open the system default device (BlackHole).
final class HALPlayback {
    private var unit: AudioUnit?
    private var renderBlock: AVAudioEngineManualRenderingBlock?
    private var customRender: ((
        UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        UnsafePointer<AudioTimeStamp>,
        UInt32,
        UnsafeMutablePointer<AudioBufferList>
    ) -> Void)?
    private var scratch: AVAudioPCMBuffer?
    private let maxFrames: AVAudioFrameCount = 8192

    func start(
        deviceID: AudioDeviceID,
        format: AVAudioFormat,
        renderBlock: @escaping AVAudioEngineManualRenderingBlock
    ) throws {
        try start(deviceID: deviceID, format: format, engineRender: renderBlock, customRender: nil)
    }

    func start(
        deviceID: AudioDeviceID,
        format: AVAudioFormat,
        onRender: @escaping (
            UnsafeMutablePointer<AudioUnitRenderActionFlags>,
            UnsafePointer<AudioTimeStamp>,
            UInt32,
            UnsafeMutablePointer<AudioBufferList>
        ) -> Void
    ) throws {
        try start(deviceID: deviceID, format: format, engineRender: nil, customRender: onRender)
    }

    private func start(
        deviceID: AudioDeviceID,
        format: AVAudioFormat,
        engineRender: AVAudioEngineManualRenderingBlock?,
        customRender: ((
            UnsafeMutablePointer<AudioUnitRenderActionFlags>,
            UnsafePointer<AudioTimeStamp>,
            UInt32,
            UnsafeMutablePointer<AudioBufferList>
        ) -> Void)?
    ) throws {
        stop()
        self.renderBlock = engineRender
        self.customRender = customRender
        if engineRender != nil {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else {
                throw DeviceManagerError.coreAudio(-1, "playback scratch buffer")
            }
            scratch = buffer
        }

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
        try check(AudioComponentInstanceNew(component, &instance), "creating playback HAL")
        guard let instance else {
            throw DeviceManagerError.noAudioUnit
        }

        var enable: UInt32 = 1
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &enable, size(enable)),
            "enable HAL playback"
        )
        var disable: UInt32 = 0
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &disable, size(disable)),
            "disable HAL capture on playback unit"
        )

        var id = deviceID
        try check(
            AudioUnitSetProperty(instance, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, size(id)),
            "playback HAL current device"
        )

        DeviceManager.setNominalSampleRate(format.sampleRate, device: deviceID)
        DeviceManager.setPreferredIOBuffer(1024, device: deviceID)

        var asbd = format.streamDescription.pointee
        try check(
            AudioUnitSetProperty(
                instance,
                kAudioUnitProperty_StreamFormat,
                kAudioUnitScope_Input,
                0,
                &asbd,
                size(asbd)
            ),
            "playback HAL stream format"
        )

        var callback = AURenderCallbackStruct(
            inputProc: halPlaybackCallback,
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )
        try check(
            AudioUnitSetProperty(instance, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback, size(callback)),
            "playback HAL render callback"
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

        try check(AudioUnitInitialize(instance), "playback HAL initialize")
        try check(AudioOutputUnitStart(instance), "playback HAL start")
        unit = instance
    }

    func stop() {
        guard let unit else {
            renderBlock = nil
            customRender = nil
            scratch = nil
            return
        }
        AudioOutputUnitStop(unit)
        AudioUnitUninitialize(unit)
        AudioComponentInstanceDispose(unit)
        self.unit = nil
        renderBlock = nil
        customRender = nil
        scratch = nil
    }

    fileprivate func render(
        flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frames: UInt32,
        ioData: UnsafeMutablePointer<AudioBufferList>?
    ) -> OSStatus {
        if let customRender, let ioData {
            customRender(flags, timestamp, frames, ioData)
            return noErr
        }
        _ = flags
        guard let ioData, let renderBlock, let scratch, frames > 0 else {
            silence(ioData, frames: frames)
            return noErr
        }
        if frames > scratch.frameCapacity {
            silence(ioData, frames: frames)
            return noErr
        }

        scratch.frameLength = frames
        let abl = UnsafeMutableAudioBufferListPointer(scratch.mutableAudioBufferList)
        for i in 0..<abl.count {
            abl[i].mDataByteSize = frames * UInt32(MemoryLayout<Float>.size)
        }
        let status = renderBlock(frames, scratch.mutableAudioBufferList, nil)
        switch status {
        case .success, .insufficientDataFromInputNode:
            copy(scratch, to: ioData, frames: Int(frames))
        default:
            silence(ioData, frames: frames)
        }
        return noErr
    }

    private func copy(_ buffer: AVAudioPCMBuffer, to ioData: UnsafeMutablePointer<AudioBufferList>, frames: Int) {
        guard frames > 0, let src = buffer.floatChannelData else {
            silence(ioData, frames: UInt32(frames))
            return
        }
        let dest = UnsafeMutableAudioBufferListPointer(ioData)
        let bytes = frames * MemoryLayout<Float>.size
        if dest.count >= 2 {
            if let data = dest[0].mData {
                memcpy(data, src[0], bytes)
                dest[0].mDataByteSize = UInt32(bytes)
            }
            if let data = dest[1].mData {
                memcpy(data, src[min(1, Int(buffer.format.channelCount) - 1)], bytes)
                dest[1].mDataByteSize = UInt32(bytes)
            }
            return
        }
        guard dest.count == 1, let data = dest[0].mData else { return }
        dest[0].mDataByteSize = UInt32(frames * Int(max(dest[0].mNumberChannels, 1)) * MemoryLayout<Float>.size)
        if dest[0].mNumberChannels >= 2 {
            let dst = data.assumingMemoryBound(to: Float.self)
            let right = buffer.format.channelCount > 1 ? src[1] : src[0]
            for i in 0..<frames {
                dst[i * 2] = src[0][i]
                dst[i * 2 + 1] = right[i]
            }
        } else {
            memcpy(data, src[0], bytes)
        }
    }

    private func silence(_ ioData: UnsafeMutablePointer<AudioBufferList>?, frames: UInt32) {
        guard let ioData, frames > 0 else { return }
        let dest = UnsafeMutableAudioBufferListPointer(ioData)
        for buffer in dest {
            if let data = buffer.mData, buffer.mDataByteSize > 0 {
                memset(data, 0, Int(buffer.mDataByteSize))
            } else if let data = buffer.mData {
                let bytes = Int(frames) * Int(max(buffer.mNumberChannels, 1)) * MemoryLayout<Float>.size
                memset(data, 0, bytes)
            }
        }
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

private func halPlaybackCallback(
    inRefCon: UnsafeMutableRawPointer,
    ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
    inTimeStamp: UnsafePointer<AudioTimeStamp>,
    inBusNumber: UInt32,
    inNumberFrames: UInt32,
    ioData: UnsafeMutablePointer<AudioBufferList>?
) -> OSStatus {
    _ = inBusNumber
    let playback = Unmanaged<HALPlayback>.fromOpaque(inRefCon).takeUnretainedValue()
    return playback.render(flags: ioActionFlags, timestamp: inTimeStamp, frames: inNumberFrames, ioData: ioData)
}
