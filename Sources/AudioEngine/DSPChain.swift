import AVFoundation
import AudioToolbox
import AudioUnit
import Accelerate
import Foundation

public final class DSPParameters: @unchecked Sendable {
    public var bass: Double = 70
    public var width: Double = 80
    public var dialogue: Double = 60
    public var room: Double = 40
    public var hrtfMix: Double = 70

    public init() {}

    public func apply(_ config: EngineConfig) {
        bass = config.bass
        width = config.width
        dialogue = config.dialogue
        room = config.room
    }

    public var sideGain: Float {
        Float(0.55 + (width / 100.0) * 1.45)
    }

    public var dialogueProtect: Float {
        Float(dialogue / 100.0)
    }

    public var bassShelfDB: Float {
        Float(-2.0 + (bass / 100.0) * 12.0)
    }

    public var presenceDB: Float {
        Float(-1.0 + (dialogue / 100.0) * 8.0)
    }

    public var highShelfDB: Float {
        1.5
    }

    public var reverbMix: Float {
        Float((room / 100.0) * 28.0)
    }

    public var limiterPreGainDB: Float {
        Float(max(0, (bass / 100.0) * 2.0))
    }
}

public final class DSPChain {
    public let eq: AVAudioUnitEQ
    public let widener: AVAudioUnit
    public let hrtf: AVAudioUnit
    public let reverb: AVAudioUnitReverb
    public let bass: AVAudioUnitEQ
    public let limiter: AVAudioUnitEffect

    public let parameters: DSPParameters
    public let hrtfUnit: HRTFAudioUnit?
    public let widenerUnit: StereoWidenerAudioUnit?

    public var nodes: [AVAudioNode] {
        [eq, widener, hrtf, reverb, bass, limiter]
    }

    public init(parameters: DSPParameters, hrtfEnabled: Bool) throws {
        self.parameters = parameters
        CustomAudioUnits.register()

        eq = AVAudioUnitEQ(numberOfBands: 3)
        bass = AVAudioUnitEQ(numberOfBands: 1)
        reverb = AVAudioUnitReverb()
        limiter = AVAudioUnitEffect(audioComponentDescription: Self.peakLimiterDescription)

        widener = try Self.instantiate(CustomAudioUnits.widenerDescription)
        hrtf = try Self.instantiate(CustomAudioUnits.hrtfDescription)

        widenerUnit = widener.auAudioUnit as? StereoWidenerAudioUnit
        hrtfUnit = hrtf.auAudioUnit as? HRTFAudioUnit
        hrtfUnit?.isBypassed = !hrtfEnabled
        widenerUnit?.parameters = parameters
        hrtfUnit?.parameters = parameters

        configureEQ()
        configureBass()
        configureReverb()
        configureLimiter()
        apply(EngineConfig.theatre)
    }

    public func apply(_ config: EngineConfig, ramp: Bool = true) {
        parameters.apply(config)
        applyAppleDSP(ramp: ramp)
        widenerUnit?.parameters = parameters
        hrtfUnit?.parameters = parameters
    }

    public func attach(to engine: AVAudioEngine) {
        for node in nodes {
            engine.attach(node)
        }
    }

    public func connect(engine: AVAudioEngine, source: AVAudioNode, format: AVAudioFormat) {
        var previous: AVAudioNode = source
        for node in nodes {
            engine.connect(previous, to: node, format: format)
            previous = node
        }
        engine.connect(previous, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
    }

    private func configureEQ() {
        eq.globalGain = 0
        let bands = eq.bands

        bands[0].filterType = .lowShelf
        bands[0].frequency = 110
        bands[0].bandwidth = 0.8
        bands[0].bypass = false

        bands[1].filterType = .parametric
        bands[1].frequency = 2500
        bands[1].bandwidth = 1.1
        bands[1].bypass = false

        bands[2].filterType = .highShelf
        bands[2].frequency = 9000
        bands[2].bandwidth = 0.7
        bands[2].bypass = false
    }

    private func configureBass() {
        bass.globalGain = 0
        let band = bass.bands[0]
        band.filterType = .lowShelf
        band.frequency = 75
        band.bandwidth = 0.7
        band.bypass = false
    }

    private func configureReverb() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 12
    }

    private func configureLimiter() {
        let audioUnit = limiter.audioUnit
        setAudioUnitParam(audioUnit, kLimiterParam_AttackTime, 0.01)
        setAudioUnitParam(audioUnit, kLimiterParam_DecayTime, 0.05)
        setAudioUnitParam(audioUnit, kLimiterParam_PreGain, 0)
    }

    private func applyAppleDSP(ramp: Bool) {
        let applyNow = {
            self.eq.bands[0].gain = self.parameters.bassShelfDB * 0.45
            self.eq.bands[1].gain = self.parameters.presenceDB
            self.eq.bands[2].gain = self.parameters.highShelfDB
            self.bass.bands[0].gain = self.parameters.bassShelfDB
            self.reverb.wetDryMix = self.parameters.reverbMix
            self.setAudioUnitParam(self.limiter.audioUnit, kLimiterParam_PreGain, self.parameters.limiterPreGainDB)
        }

        if ramp {
            let steps = 8
            for step in 1...steps {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.012 * Double(step)) {
                    applyNow()
                }
            }
        } else {
            applyNow()
        }
    }

    private func setAudioUnitParam(_ audioUnit: AudioUnit, _ parameter: AudioUnitParameterID, _ value: Float) {
        AudioUnitSetParameter(audioUnit, parameter, kAudioUnitScope_Global, 0, value, 0)
    }

    private static var peakLimiterDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }

    private static func instantiate(_ description: AudioComponentDescription) throws -> AVAudioUnit {
        let lock = DispatchSemaphore(value: 0)
        var unit: AVAudioUnit?
        var instantiateError: Error?
        AVAudioUnit.instantiate(with: description, options: []) { created, error in
            unit = created
            instantiateError = error
            lock.signal()
        }
        lock.wait()
        if let instantiateError {
            throw instantiateError
        }
        guard let unit else {
            throw DSPChainError.instantiationFailed
        }
        return unit
    }
}

public enum DSPChainError: Error {
    case instantiationFailed
}

enum CustomAudioUnits {
    static let widenerDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: fourChar("WDNR"),
        componentManufacturer: fourChar("CENG"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    static let hrtfDescription = AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: fourChar("HRTF"),
        componentManufacturer: fourChar("CENG"),
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private static var registered = false

    static func register() {
        guard !registered else { return }
        AUAudioUnit.registerSubclass(
            StereoWidenerAudioUnit.self,
            as: widenerDescription,
            name: "CinemaEngine:Widener",
            version: 1
        )
        AUAudioUnit.registerSubclass(
            HRTFAudioUnit.self,
            as: hrtfDescription,
            name: "CinemaEngine:HRTF",
            version: 1
        )
        registered = true
    }
}

func fourChar(_ string: String) -> OSType {
    var value: OSType = 0
    for byte in string.utf8.prefix(4) {
        value = (value << 8) | OSType(byte)
    }
    return value
}

struct Biquad {
    var b0: Float = 1
    var b1: Float = 0
    var b2: Float = 0
    var a1: Float = 0
    var a2: Float = 0
    var z1: Float = 0
    var z2: Float = 0

    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    mutating func reset() {
        z1 = 0
        z2 = 0
    }

    static func lowpass(freq: Float, sampleRate: Float, q: Float = 0.707) -> Biquad {
        rbj(freq: freq, sampleRate: sampleRate, q: q, type: .lowpass)
    }

    static func highpass(freq: Float, sampleRate: Float, q: Float = 0.707) -> Biquad {
        rbj(freq: freq, sampleRate: sampleRate, q: q, type: .highpass)
    }

    private enum Kind { case lowpass, highpass }

    private static func rbj(freq: Float, sampleRate: Float, q: Float, type: Kind) -> Biquad {
        let clamped = max(20, min(freq, sampleRate * 0.45))
        let w0 = 2 * Float.pi * clamped / sampleRate
        let cosw = cos(w0)
        let sinw = sin(w0)
        let alpha = sinw / (2 * max(q, 0.1))
        let a0: Float
        var filter = Biquad()
        switch type {
        case .lowpass:
            a0 = 1 + alpha
            filter.b0 = ((1 - cosw) / 2) / a0
            filter.b1 = (1 - cosw) / a0
            filter.b2 = ((1 - cosw) / 2) / a0
            filter.a1 = (-2 * cosw) / a0
            filter.a2 = (1 - alpha) / a0
        case .highpass:
            a0 = 1 + alpha
            filter.b0 = ((1 + cosw) / 2) / a0
            filter.b1 = (-(1 + cosw)) / a0
            filter.b2 = ((1 + cosw) / 2) / a0
            filter.a1 = (-2 * cosw) / a0
            filter.a2 = (1 - alpha) / a0
        }
        return filter
    }
}

final class WidenerState {
    var sampleRate: Double = 48000
    var smoothedWidth: Float = 1.2
    var smoothedProtect: Float = 0.6
    var hpL = Biquad.highpass(freq: 300, sampleRate: 48000)
    var lpL = Biquad.lowpass(freq: 3000, sampleRate: 48000)
    var hpR = Biquad.highpass(freq: 300, sampleRate: 48000)
    var lpR = Biquad.lowpass(freq: 3000, sampleRate: 48000)

    func updateSampleRate(_ rate: Double) {
        guard abs(rate - sampleRate) > 1 else { return }
        sampleRate = rate
        hpL = Biquad.highpass(freq: 300, sampleRate: Float(rate))
        lpL = Biquad.lowpass(freq: 3000, sampleRate: Float(rate))
        hpR = Biquad.highpass(freq: 300, sampleRate: Float(rate))
        lpR = Biquad.lowpass(freq: 3000, sampleRate: Float(rate))
    }
}

@objc(StereoWidenerAudioUnit)
public final class StereoWidenerAudioUnit: AUAudioUnit {
    public var parameters = DSPParameters()
    private let state = WidenerState()
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
        state.updateSampleRate(outputBus.format.sampleRate)
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let state = self.state
        let parameters = self.parameters
        return { _, timestamp, frameCount, _, outputData, _, pullInputBlock in
            guard let pullInputBlock else { return kAudioUnitErr_NoConnection }
            var flags: AudioUnitRenderActionFlags = []
            let status = pullInputBlock(&flags, timestamp, frameCount, 0, outputData)
            guard status == noErr else { return status }

            let abl = UnsafeMutableAudioBufferListPointer(outputData)
            guard abl.count >= 1, frameCount > 0 else { return noErr }

            let dt = Float(frameCount) / Float(max(state.sampleRate, 1))
            let coeff = 1 - expf(-dt / 0.1)
            state.smoothedWidth += (parameters.sideGain - state.smoothedWidth) * coeff
            state.smoothedProtect += (parameters.dialogueProtect - state.smoothedProtect) * coeff

            processWidener(abl: abl, frames: Int(frameCount), state: state)
            return noErr
        }
    }
}

private func processWidener(abl: UnsafeMutableAudioBufferListPointer, frames: Int, state: WidenerState) {
    let width = state.smoothedWidth
    let protect = state.smoothedProtect

    if abl.count >= 2,
       let left = abl[0].mData?.assumingMemoryBound(to: Float.self),
       let right = abl[1].mData?.assumingMemoryBound(to: Float.self)
    {
        for i in 0..<frames {
            let l = left[i]
            let r = right[i]
            let processed = widenSample(l: l, r: r, width: width, protect: protect, state: state)
            left[i] = processed.0
            right[i] = processed.1
        }
        return
    }

    guard let interleaved = abl[0].mData?.assumingMemoryBound(to: Float.self) else { return }
    let channels = Int(abl[0].mNumberChannels)
    guard channels >= 2 else { return }
    for i in 0..<frames {
        let l = interleaved[i * channels]
        let r = interleaved[i * channels + 1]
        let processed = widenSample(l: l, r: r, width: width, protect: protect, state: state)
        interleaved[i * channels] = processed.0
        interleaved[i * channels + 1] = processed.1
    }
}

private func widenSample(l: Float, r: Float, width: Float, protect: Float, state: WidenerState) -> (Float, Float) {
    let mid = 0.5 * (l + r)
    let side = 0.5 * (l - r)
    let dialogueBand = state.lpL.process(state.hpL.process(side))
    let rest = side - dialogueBand
    let dialogueScale = 1 + (width - 1) * (1 - protect)
    let wideSide = rest * width + dialogueBand * dialogueScale
    return (mid + wideSide, mid - wideSide)
}
