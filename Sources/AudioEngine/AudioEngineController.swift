import AVFoundation
import Accelerate
import Foundation
import Darwin

public final class AudioEngineController {
    private var engine = AVAudioEngine()
    private let watcher = ConfigWatcher()
    private var chain: DSPChain?
    private var config: EngineConfig
    private var inputDevice: AudioDeviceInfo?
    private var outputDevice: AudioDeviceInfo?
    private var statusTimer: DispatchSourceTimer?
    private var peakL: Float = 0
    private var peakR: Float = 0
    private let hrtfEnabled: Bool
    private let autoRoute: Bool
    private var stopping = false
    private var didEngageRouting = false
    private var interruptSource: DispatchSourceSignal?
    private var terminateSource: DispatchSourceSignal?
    private var quiet = false
    private var didInstallTap = false
    private var syncedIO: SyncedIO?
    private var sourceNode: AVAudioSourceNode?

    public var willExit: (() -> Void)?

    public init(config: EngineConfig, hrtfEnabled: Bool = true, autoRoute: Bool = true) {
        self.config = config.clamped()
        self.hrtfEnabled = hrtfEnabled
        self.autoRoute = autoRoute
    }

    public var liveConfig: EngineConfig { config }

    public var snapshot: EngineSnapshot {
        EngineSnapshot(
            config: config,
            peakL: syncedIO?.peakL ?? peakL,
            peakR: syncedIO?.peakR ?? peakR,
            inputName: inputDevice?.name ?? config.inputDevice,
            outputName: outputDevice?.name ?? config.outputDevice,
            running: engine.isRunning,
            hrtfLabel: hrtfLabel
        )
    }

    public func run(interactive: Bool = false) throws {
        quiet = interactive
        try startAudio()
        watcher.start { [weak self] newConfig in
            DispatchQueue.main.async {
                self?.apply(newConfig, ramp: true)
            }
        }
        installSignalHandlers()
        if interactive {
            return
        }
        startStatusTimer()
        RunLoop.main.run()
    }

    public func applyLive(_ newConfig: EngineConfig, ramp: Bool) {
        apply(newConfig, ramp: ramp)
        try? config.save()
    }

    public func tick() {
        peakL *= 0.9
        peakR *= 0.9
        writeState()
    }

    private func startAudio() throws {
        if let existing = RuntimeControl.runningPid(), existing != ProcessInfo.processInfo.processIdentifier {
            throw EngineError.alreadyRunning(existing)
        }

        if RuntimeControl.runningPid() == nil {
            _ = SystemRouting.restore()
        }

        try CinemaPaths.ensureDirectory()

        var input: AudioDeviceInfo
        do {
            input = try DeviceManager.resolveInput(query: config.inputDevice)
        } catch {
            throw EngineError.blackHoleMissing
        }
        var output = try DeviceManager.resolveOutput(query: config.outputDevice, excluding: input)
        if input.id == output.id {
            throw EngineError.feedbackLoop(input.name)
        }

        config.inputDevice = input.name
        config.outputDevice = output.name
        try config.save()
        try RuntimeControl.writePid()

        input = DeviceManager.refresh(input, role: .input)
        output = DeviceManager.refresh(output, role: .output)
        inputDevice = input
        outputDevice = output

        rebuildEngine()

        let sampleRate = preferredSampleRate(input: input, output: output)
        DeviceManager.setPreferredIOBuffer(1024, device: input.id)
        DeviceManager.setPreferredIOBuffer(1024, device: output.id)
        DeviceManager.setNominalSampleRate(sampleRate, device: input.id)
        DeviceManager.setNominalSampleRate(sampleRate, device: output.id)
        DeviceManager.preparePlayback(output)
        guard let processingFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            abortStart()
            throw EngineError.invalidInputFormat
        }

        do {
            let io = SyncedIO()
            self.syncedIO = io

            let source = AVAudioSourceNode(format: processingFormat) { _, _, frameCount, abl -> OSStatus in
                io.copyInput(into: abl, frames: Int(frameCount))
                return noErr
            }
            sourceNode = source
            engine.attach(source)

            let chain = try DSPChain(parameters: DSPParameters(), hrtfEnabled: hrtfEnabled)
            chain.apply(config, ramp: false)
            chain.attach(to: engine)
            self.chain = chain
            chain.connect(engine: engine, source: source, format: processingFormat)

            try engine.enableManualRenderingMode(
                .realtime,
                format: processingFormat,
                maximumFrameCount: 8192
            )
            try engine.start()
            try io.start(
                blackHole: input,
                playback: output,
                format: processingFormat,
                renderBlock: engine.manualRenderingBlock
            )
            DeviceManager.preparePlayback(output)

            if autoRoute {
                try SystemRouting.engage(blackHole: input, playback: output)
                didEngageRouting = true
            }

            if !quiet {
                printStartupBanner(input: input, output: output, format: processingFormat)
            }
        } catch {
            abortStart()
            throw error
        }
    }

    public func shutdown() {
        guard !stopping else { return }
        stopping = true
        statusTimer?.cancel()
        watcher.stop()
        abortEngine()
        let restored = didEngageRouting ? SystemRouting.restore() : nil
        RuntimeControl.clearPid()
        willExit?()
        if quiet {
            fputs("cinema-engine stopped. Audio is back to normal.\n", stdout)
        } else if let restored {
            fputs("\nRestored system output to \(restored).\nStopped cinema-engine.\n", stdout)
        } else {
            fputs("\nStopped cinema-engine.\n", stdout)
        }
        fflush(stdout)
        exit(0)
    }

    private func rebuildEngine() {
        abortEngine()
        engine = AVAudioEngine()
    }

    private func abortStart() {
        abortEngine()
        if didEngageRouting {
            SystemRouting.restore()
            didEngageRouting = false
        }
        RuntimeControl.clearPid()
    }

    private func abortEngine() {
        if didInstallTap {
            engine.mainMixerNode.removeTap(onBus: 0)
            didInstallTap = false
        }
        syncedIO?.stop()
        syncedIO = nil
        if engine.isRunning {
            engine.stop()
        }
        engine.reset()
        if engine.isInManualRenderingMode {
            engine.disableManualRenderingMode()
        }
        chain = nil
        sourceNode = nil
    }

    private func preferredSampleRate(input: AudioDeviceInfo, output: AudioDeviceInfo) -> Double {
        let rates = [input.sampleRate, output.sampleRate, 48_000, 44_100]
        return rates.first(where: { $0 >= 44_100 }) ?? 48_000
    }

    private func apply(_ newConfig: EngineConfig, ramp: Bool = true) {
        var merged = newConfig.clamped()
        merged.inputDevice = config.inputDevice
        merged.outputDevice = config.outputDevice
        guard merged != config else { return }
        config = merged
        chain?.apply(config, ramp: ramp)
    }

    private var hrtfLabel: String {
        if !hrtfEnabled {
            return "off"
        }
        if chain?.hrtfUnit?.loadedFromDisk == true {
            return "KEMAR"
        }
        return "synthetic front"
    }

    private func installMeters(format: AVAudioFormat) {
        if didInstallTap {
            engine.mainMixerNode.removeTap(onBus: 0)
        }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 256, format: format) { [weak self] buffer, _ in
            guard let self, let data = buffer.floatChannelData else { return }
            let frames = Int(buffer.frameLength)
            let channels = Int(buffer.format.channelCount)
            var l: Float = 0
            var r: Float = 0
            if channels >= 2 {
                vabsMax(data[0], frames, &l)
                vabsMax(data[1], frames, &r)
            } else if channels == 1 {
                vabsMax(data[0], frames, &l)
                r = l
            }
            self.peakL = max(self.peakL * 0.82, l)
            self.peakR = max(self.peakR * 0.82, r)
        }
        didInstallTap = true
    }

    private func installSignalHandlers() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        let sigint = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        let sigterm = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        sigint.setEventHandler { [weak self] in self?.shutdown() }
        sigterm.setEventHandler { [weak self] in self?.shutdown() }
        sigint.resume()
        sigterm.resume()
        interruptSource = sigint
        terminateSource = sigterm
    }

    private func startStatusTimer() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.2, repeating: 0.15)
        timer.setEventHandler { [weak self] in
            self?.printStatusLine()
            self?.writeState()
        }
        timer.resume()
        statusTimer = timer
    }

    private func printStartupBanner(input: AudioDeviceInfo, output: AudioDeviceInfo, format: AVAudioFormat) {
        print("cinema-engine running")
        print("  input : \(input.name)  (system output is now this device)")
        print("  output: \(output.name)")
        print("  rate  : \(Int(format.sampleRate)) Hz, \(format.channelCount) ch")
        print("  buffer: \(DeviceManager.bufferFrameSize(device: input.id)) frames (target < 40 ms)")
        print("  hrtf  : \(hrtfLabel)")
        print("  preset: \(config.preset)")
        print("q or Ctrl+C to quit — audio returns to normal.\n")
    }

    private func printStatusLine() {
        let meterL = meterBar(syncedIO?.peakL ?? peakL)
        let meterR = meterBar(syncedIO?.peakR ?? peakR)
        let line = String(
            format: "\u{001B}[2K\r  [%@] bass:%2.0f  width:%2.0f  dialogue:%2.0f  room:%2.0f  | L:%@ R:%@ | %@ → %@",
            config.preset,
            config.bass,
            config.width,
            config.dialogue,
            config.room,
            meterL,
            meterR,
            inputDevice?.name ?? "?",
            outputDevice?.name ?? "?"
        )
        fputs(line, stdout)
        fflush(stdout)
        peakL *= 0.9
        peakR *= 0.9
    }

    private func writeState() {
        let buffer = inputDevice.map { Int(DeviceManager.bufferFrameSize(device: $0.id)) } ?? 0
        let state = RuntimeState(
            active: engine.isRunning,
            pid: ProcessInfo.processInfo.processIdentifier,
            config: config,
            peakL: Double(syncedIO?.peakL ?? peakL),
            peakR: Double(syncedIO?.peakR ?? peakR),
            sampleRate: engine.isInManualRenderingMode ? engine.manualRenderingFormat.sampleRate : 0,
            bufferFrames: buffer,
            hrtfEnabled: hrtfEnabled && !(chain?.hrtfUnit?.isBypassed ?? true)
        )
        state.save()
    }

    private func meterBar(_ peak: Float) -> String {
        let filled = min(8, max(0, Int((peak * 8).rounded(.down))))
        return String(repeating: "█", count: filled) + String(repeating: "░", count: 8 - filled)
    }

}

public enum EngineError: Error, CustomStringConvertible {
    case alreadyRunning(pid_t)
    case feedbackLoop(String)
    case invalidInputFormat
    case microphoneDenied
    case blackHoleMissing
    case blackHoleInstallFailed

    public var description: String {
        switch self {
        case .alreadyRunning(let pid):
            return "cinema-engine is already running (pid \(pid)). Use `cinema-engine stop` first."
        case .feedbackLoop(let name):
            return "Input and output are both '\(name)'. Choose a different output (e.g. AirPods) to avoid a feedback loop."
        case .invalidInputFormat:
            return "Could not open the audio input. Allow Microphone for your terminal in System Settings > Privacy & Security > Microphone, then run start again."
        case .microphoneDenied:
            return "Microphone access was denied. Enable it in System Settings > Privacy & Security > Microphone."
        case .blackHoleMissing:
            return "BlackHole is not installed. Run ./install.sh once (it will ask for your Mac password)."
        case .blackHoleInstallFailed:
            return "Could not install BlackHole automatically. Run ./install.sh in Terminal."
        }
    }
}

private func vabsMax(_ ptr: UnsafePointer<Float>, _ frames: Int, _ out: inout Float) {
    var value: Float = 0
    vDSP_maxmgv(ptr, 1, &value, vDSP_Length(frames))
    out = value
}

public struct EngineSnapshot: Sendable {
    public var config: EngineConfig
    public var peakL: Float
    public var peakR: Float
    public var inputName: String
    public var outputName: String
    public var running: Bool
    public var hrtfLabel: String
}
