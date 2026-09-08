import AVFoundation
import AudioToolbox
import AudioUnit
import Accelerate
import Darwin
import Foundation

/// FFT overlap-add convolver. Preallocated; no heap traffic on the audio thread.
final class FFTConvolver {
    private let fftSize: Int
    private let irLength: Int
    private let fft: vDSP.FFT<DSPSplitComplex>
    private var irReal: [Float]
    private var irImag: [Float]
    private var timeReal: [Float]
    private var timeImag: [Float]
    private var specReal: [Float]
    private var specImag: [Float]
    private var overlap: [Float]
    private var overlapScratch: [Float]
    private let scale: Float

    init?(impulse: [Float], maxFrames: Int = 2048) {
        let irCount = max(impulse.count, 1)
        let needed = maxFrames + irCount - 1
        let size = 1 << Int(ceil(log2(Double(max(needed, 32)))))
        guard size <= 8192 else { return nil }
        let log2n = vDSP_Length(log2(Double(size)))
        guard let fft = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self) else {
            return nil
        }
        self.fft = fft
        fftSize = size
        irLength = irCount
        scale = 1.0 / Float(size)
        irReal = [Float](repeating: 0, count: size)
        irImag = [Float](repeating: 0, count: size)
        timeReal = [Float](repeating: 0, count: size)
        timeImag = [Float](repeating: 0, count: size)
        specReal = [Float](repeating: 0, count: size)
        specImag = [Float](repeating: 0, count: size)
        overlap = [Float](repeating: 0, count: size)
        overlapScratch = [Float](repeating: 0, count: size)

        let copyCount = min(impulse.count, size)
        for i in 0..<copyCount {
            irReal[i] = impulse[i]
        }
        transformIR()
    }

    func reset() {
        for i in 0..<overlap.count { overlap[i] = 0 }
    }

    func process(input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0, frames < fftSize else {
            if frames > 0 {
                output.update(from: input, count: frames)
            }
            return
        }

        for i in 0..<fftSize {
            timeReal[i] = i < frames ? input[i] : 0
            timeImag[i] = 0
        }

        timeReal.withUnsafeMutableBufferPointer { timeR in
            timeImag.withUnsafeMutableBufferPointer { timeI in
                specReal.withUnsafeMutableBufferPointer { specR in
                    specImag.withUnsafeMutableBufferPointer { specI in
                        irReal.withUnsafeMutableBufferPointer { irR in
                            irImag.withUnsafeMutableBufferPointer { irI in
                                var time = DSPSplitComplex(realp: timeR.baseAddress!, imagp: timeI.baseAddress!)
                                var spec = DSPSplitComplex(realp: specR.baseAddress!, imagp: specI.baseAddress!)
                                var ir = DSPSplitComplex(realp: irR.baseAddress!, imagp: irI.baseAddress!)
                                fft.forward(input: time, output: &spec)
                                let n = vDSP_Length(fftSize)
                                vDSP_zvmul(&spec, 1, &ir, 1, &spec, 1, n, 1)
                                fft.inverse(input: spec, output: &time)
                            }
                        }
                    }
                }
            }
        }

        for i in 0..<frames {
            output[i] = timeReal[i] * scale + overlap[i]
        }

        for i in 0..<fftSize {
            overlapScratch[i] = 0
        }
        let tail = fftSize - frames
        if tail > 0 {
            for i in 0..<tail {
                overlapScratch[i] = timeReal[i + frames] * scale
            }
        }
        let previousTail = max(irLength - 1 - frames, 0)
        if previousTail > 0 {
            for i in 0..<previousTail {
                overlapScratch[i] += overlap[i + frames]
            }
        }
        for i in 0..<fftSize {
            overlap[i] = overlapScratch[i]
        }
    }

    private func transformIR() {
        irReal.withUnsafeMutableBufferPointer { real in
            irImag.withUnsafeMutableBufferPointer { imag in
                var split = DSPSplitComplex(realp: real.baseAddress!, imagp: imag.baseAddress!)
                fft.forward(input: split, output: &split)
            }
        }
    }
}

public final class HRTFProcessor {
    private var left: FFTConvolver
    private var right: FFTConvolver
    private var smoothedMix: Float = 0.7

    public let loadedFromDisk: Bool

    public init(sampleRate: Double) {
        let loaded = HRTFImpulseLoader.load(sampleRate: sampleRate)
        loadedFromDisk = loaded.fromDisk
        left = FFTConvolver(impulse: loaded.left)!
        right = FFTConvolver(impulse: loaded.right)!
    }

    public func process(
        leftIn: UnsafePointer<Float>,
        rightIn: UnsafePointer<Float>,
        leftOut: UnsafeMutablePointer<Float>,
        rightOut: UnsafeMutablePointer<Float>,
        frames: Int,
        mix: Float,
        sampleRate: Double
    ) {
        let dt = Float(frames) / Float(max(sampleRate, 1))
        let coeff = 1 - expf(-dt / 0.1)
        smoothedMix += (mix - smoothedMix) * coeff
        let wet = smoothedMix
        let dry = 1 - wet * 0.85

        left.process(input: leftIn, output: leftOut, frames: frames)
        right.process(input: rightIn, output: rightOut, frames: frames)

        for i in 0..<frames {
            leftOut[i] = dry * leftIn[i] + wet * leftOut[i]
            rightOut[i] = dry * rightIn[i] + wet * rightOut[i]
        }
    }
}

enum HRTFImpulseLoader {
    struct Result {
        var left: [Float]
        var right: [Float]
        var fromDisk: Bool
    }

    static func load(sampleRate: Double) -> Result {
        let urls = candidateDirectories()
        for directory in urls {
            if let pair = loadPair(from: directory, sampleRate: sampleRate) {
                return Result(left: pair.0, right: pair.1, fromDisk: true)
            }
            if let mono = loadMono(from: directory, sampleRate: sampleRate) {
                return Result(left: mono, right: mono, fromDisk: true)
            }
        }
        let synthetic = syntheticFrontIR(sampleRate: sampleRate)
        return Result(left: synthetic.0, right: synthetic.1, fromDisk: false)
    }

    static func candidateDirectories() -> [URL] {
        var urls: [URL] = []
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        urls.append(cwd.appendingPathComponent("hrtf-data"))
        urls.append(CinemaPaths.directory.appendingPathComponent("hrtf-data"))

        if let exec = Bundle.main.executableURL {
            let folder = exec.deletingLastPathComponent()
            urls.append(folder.appendingPathComponent("hrtf-data"))
            urls.append(folder.appendingPathComponent("../hrtf-data").standardized)
            urls.append(folder.appendingPathComponent("../../hrtf-data").standardized)
            urls.append(folder.appendingPathComponent("../../../hrtf-data").standardized)
        }
        return urls
    }

    private static func loadPair(from directory: URL, sampleRate: Double) -> ([Float], [Float])? {
        let names = [
            ("front_left.wav", "front_right.wav"),
            ("H10e000a.wav", "H10e000a.wav"),
            ("left.wav", "right.wav")
        ]
        for (leftName, rightName) in names {
            let leftURL = directory.appendingPathComponent(leftName)
            let rightURL = directory.appendingPathComponent(rightName)
            if let left = loadWAV(leftURL, sampleRate: sampleRate),
               let right = loadWAV(rightURL, sampleRate: sampleRate)
            {
                return (left, right)
            }
        }
        return nil
    }

    private static func loadMono(from directory: URL, sampleRate: Double) -> [Float]? {
        let names = ["H10e000a.wav", "H0e000a.wav", "front.wav", "kemar_front.wav"]
        for name in names {
            if let ir = loadWAV(directory.appendingPathComponent(name), sampleRate: sampleRate) {
                return ir
            }
        }
        return nil
    }

    private static func loadWAV(_ url: URL, sampleRate: Double) -> [Float]? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            return nil
        }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        guard let channel = buffer.floatChannelData?[0] else { return nil }
        var samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        if abs(format.sampleRate - sampleRate) > 1 {
            samples = resample(samples, from: format.sampleRate, to: sampleRate)
        }
        normalizePeak(&samples, peak: 0.9)
        return samples
    }

    private static func resample(_ input: [Float], from: Double, to: Double) -> [Float] {
        guard from > 0, to > 0, !input.isEmpty else { return input }
        let ratio = to / from
        let count = max(Int(Double(input.count) * ratio), 1)
        var output = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let src = Double(i) / ratio
            let idx = Int(src)
            let frac = Float(src - Double(idx))
            let a = input[min(idx, input.count - 1)]
            let b = input[min(idx + 1, input.count - 1)]
            output[i] = a + (b - a) * frac
        }
        return output
    }

    private static func normalizePeak(_ samples: inout [Float], peak: Float) {
        var maxv: Float = 0
        vDSP_maxmgv(samples, 1, &maxv, vDSP_Length(samples.count))
        guard maxv > 0.0001 else { return }
        var scale = peak / maxv
        vDSP_vsmul(samples, 1, &scale, &samples, 1, vDSP_Length(samples.count))
    }

    /// Compact "in front, slightly above" stand-in when KEMAR files are absent.
    /// Front-loaded, nearly identical L/R with a tiny pinna-style coloration.
    static func syntheticFrontIR(sampleRate: Double) -> ([Float], [Float]) {
        let n = Int(0.008 * sampleRate) // ~8 ms
        var left = [Float](repeating: 0, count: max(n, 64))
        var right = [Float](repeating: 0, count: max(n, 64))
        for i in 0..<left.count {
            let t = Float(i) / Float(sampleRate)
            let env = expf(-t * 680)
            let pinna = sinf(2 * Float.pi * 3800 * t) * 0.18
            let body = (i == 0 ? 0.95 : 0) + pinna * env
            left[i] = body * env
            right[i] = body * env * 0.98
        }
        if left.count > 2 {
            left[1] += 0.22
            right[1] += 0.20
        }
        if left.count > 6 {
            left[5] -= 0.08
            right[6] -= 0.09
        }
        normalizePeak(&left, peak: 1.0)
        normalizePeak(&right, peak: 1.0)
        return (left, right)
    }
}

final class HRTFRenderState {
    var processor: HRTFProcessor
    var sampleRate: Double
    var scratchL: [Float]
    var scratchR: [Float]
    var inL: [Float]
    var inR: [Float]
    var bypassed = false
    var mix: Float = 0.7

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        processor = HRTFProcessor(sampleRate: sampleRate)
        scratchL = [Float](repeating: 0, count: 4096)
        scratchR = [Float](repeating: 0, count: 4096)
        inL = [Float](repeating: 0, count: 4096)
        inR = [Float](repeating: 0, count: 4096)
    }

    func rebuildIfNeeded(_ rate: Double) {
        guard abs(rate - sampleRate) > 1 else { return }
        sampleRate = rate
        processor = HRTFProcessor(sampleRate: rate)
    }
}

@objc(HRTFAudioUnit)
public final class HRTFAudioUnit: AUAudioUnit {
    public var parameters = DSPParameters()
    public var isBypassed: Bool {
        get { state.bypassed }
        set { state.bypassed = newValue }
    }
    public var loadedFromDisk: Bool { state.processor.loadedFromDisk }

    private var state: HRTFRenderState
    private var inputBusArrayStorage: AUAudioUnitBusArray!
    private var outputBusArrayStorage: AUAudioUnitBusArray!
    private let inputBus: AUAudioUnitBus
    private let outputBus: AUAudioUnitBus

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        inputBus = try AUAudioUnitBus(format: format)
        outputBus = try AUAudioUnitBus(format: format)
        inputBus.maximumChannelCount = 2
        outputBus.maximumChannelCount = 2
        state = HRTFRenderState(sampleRate: 48_000)
        try super.init(componentDescription: componentDescription, options: options)
        inputBusArrayStorage = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [inputBus])
        outputBusArrayStorage = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        maximumFramesToRender = 4096
    }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArrayStorage }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArrayStorage }
    public override var canProcessInPlace: Bool { true }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        state.rebuildIfNeeded(outputBus.format.sampleRate)
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let state = self.state
        let parameters = self.parameters
        return { _, timestamp, frameCount, _, outputData, _, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            var flags: AudioUnitRenderActionFlags = []
            let status = pullInputBlock(&flags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }
            if state.bypassed { return noErr }

            let frames = Int(frameCount)
            guard frames > 0, frames <= 4096 else { return noErr }

            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            copyToPlanar(abl: abl, frames: frames, left: &state.inL, right: &state.inR)

            let mix = Float(parameters.hrtfMix / 100.0)
            state.inL.withUnsafeMutableBufferPointer { inL in
                state.inR.withUnsafeMutableBufferPointer { inR in
                    state.scratchL.withUnsafeMutableBufferPointer { outL in
                        state.scratchR.withUnsafeMutableBufferPointer { outR in
                            state.processor.process(
                                leftIn: inL.baseAddress!,
                                rightIn: inR.baseAddress!,
                                leftOut: outL.baseAddress!,
                                rightOut: outR.baseAddress!,
                                frames: frames,
                                mix: mix,
                                sampleRate: state.sampleRate
                            )
                        }
                    }
                }
            }

            copyFromPlanar(abl: abl, frames: frames, left: state.scratchL, right: state.scratchR)
            return noErr
        }
    }
}

private func copyToPlanar(abl: UnsafeMutableAudioBufferListPointer, frames: Int, left: inout [Float], right: inout [Float]) {
    left.withUnsafeMutableBufferPointer { leftBuf in
        right.withUnsafeMutableBufferPointer { rightBuf in
            guard let leftPtr = leftBuf.baseAddress, let rightPtr = rightBuf.baseAddress else { return }
            if abl.count >= 2,
               let l = abl[0].mData?.assumingMemoryBound(to: Float.self),
               let r = abl[1].mData?.assumingMemoryBound(to: Float.self)
            {
                memcpy(leftPtr, l, frames * MemoryLayout<Float>.size)
                memcpy(rightPtr, r, frames * MemoryLayout<Float>.size)
                return
            }
            guard let interleaved = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return }
            let channels = Int(max(abl[0].mNumberChannels, 1))
            if channels == 1 {
                memcpy(leftPtr, interleaved, frames * MemoryLayout<Float>.size)
                memcpy(rightPtr, interleaved, frames * MemoryLayout<Float>.size)
                return
            }
            for i in 0..<frames {
                leftPtr[i] = interleaved[i * channels]
                rightPtr[i] = interleaved[i * channels + 1]
            }
        }
    }
}

private func copyFromPlanar(abl: UnsafeMutableAudioBufferListPointer, frames: Int, left: [Float], right: [Float]) {
    if abl.count >= 2,
       let l = abl[0].mData?.assumingMemoryBound(to: Float.self),
       let r = abl[1].mData?.assumingMemoryBound(to: Float.self)
    {
        l.update(from: left, count: frames)
        r.update(from: right, count: frames)
        return
    }
    guard let interleaved = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return }
    let channels = Int(max(abl[0].mNumberChannels, 1))
    if channels == 1 {
        interleaved.update(from: left, count: frames)
        return
    }
    for i in 0..<frames {
        interleaved[i * channels] = left[i]
        interleaved[i * channels + 1] = right[i]
    }
}
