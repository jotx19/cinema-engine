import AppKit
import AVFoundation
import AudioEngine
import Combine
import Foundation
import SwiftUI

@MainActor
final class EngineModel: ObservableObject {
    @Published var config: EngineConfig = .theatre
    @Published var running = false
    @Published var starting = false
    @Published var installingBlackHole = false
    @Published var blackHoleInstalled = false
    @Published var errorMessage: String?
    @Published var inputName = "—"
    @Published var outputName = "—"
    @Published var hrtfLabel = "—"
    @Published var peakL: Float = 0
    @Published var peakR: Float = 0
    @Published var selectedPreset = "theatre"
    @Published var outputDevices: [AudioDeviceInfo] = []
    @Published var preferredOutputName = "—"

    private var controller: AudioEngineController?
    private var timer: AnyCancellable?

    init() {
        config = EngineConfig.load()
        selectedPreset = config.preset
        refreshDevices()
    }

    func refreshDevices() {
        blackHoleInstalled = BlackHoleInstaller.isInstalled()
        do {
            let devices = try DeviceManager.listDevices()
                .filter { device in
                    device.isOutput
                        && !DeviceManager.isVirtualLoopback(device)
                        && !Self.isHiddenOutput(device.name)
                }
                .sorted { DeviceIconsSort.rank($0.name) < DeviceIconsSort.rank($1.name) }
            outputDevices = devices
            if let preferred = try? DeviceManager.preferredPlaybackDevice() {
                preferredOutputName = preferred.name
                if !running, config.outputDevice == "auto" || config.outputDevice.isEmpty {
                    outputName = preferred.name
                } else if !running {
                    outputName = config.outputDevice == "auto" ? preferred.name : config.outputDevice
                }
            }
        } catch {
            outputDevices = []
        }
    }

    func selectOutput(_ device: AudioDeviceInfo) {
        let alreadySelected = config.outputDevice == device.name
            || (config.outputDevice == "auto" && device.name == preferredOutputName && device.name == outputName)
        if alreadySelected, !running {
            // Still push system default in case another app changed it.
            try? DeviceManager.setDefaultOutputDevice(device)
            return
        }
        if alreadySelected, running { return }

        errorMessage = nil
        config.outputDevice = device.name
        preferredOutputName = device.name
        outputName = device.name
        try? config.save()

        if running {
            // Restart onto the new playback device while cinema mode stays on.
            stop()
            start()
            return
        }

        // Not running: set system default output immediately.
        do {
            try DeviceManager.setDefaultOutputDevice(device)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func toggle() {
        if running {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard !running, !starting else { return }
        refreshDevices()
        guard blackHoleInstalled else {
            errorMessage = "BlackHole is required. Install it to use Cinema Engine."
            return
        }

        starting = true
        errorMessage = nil

        let snapshotConfig = config
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                var next = EngineConfig.load()
                next.bass = snapshotConfig.bass
                next.width = snapshotConfig.width
                next.dialogue = snapshotConfig.dialogue
                next.room = snapshotConfig.room
                next.preset = snapshotConfig.preset
                next.outputDevice = snapshotConfig.outputDevice
                next = next.clamped()
                try next.save()

                let controller = AudioEngineController(config: next, hrtfEnabled: true, autoRoute: true)
                try controller.run(interactive: true)

                DispatchQueue.main.async {
                    guard let self else { return }
                    self.controller = controller
                    self.running = true
                    self.starting = false
                    self.refreshSnapshot()
                    self.refreshDevices()
                    self.startPolling()
                    AVCaptureDevice.requestAccess(for: .audio) { _ in }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.starting = false
                    self?.errorMessage = String(describing: error)
                    self?.refreshDevices()
                }
            }
        }
    }

    func installBlackHole() {
        guard !installingBlackHole else { return }
        installingBlackHole = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try BlackHoleInstaller.install(usingShellCommand: Self.runCommand)
                DispatchQueue.main.async {
                    self?.installingBlackHole = false
                    self?.refreshDevices()
                    if self?.blackHoleInstalled == true {
                        self?.errorMessage = nil
                    } else {
                        self?.errorMessage = "BlackHole still not found. Run the install script from the website, then reopen the widget."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self?.installingBlackHole = false
                    self?.errorMessage = String(describing: error)
                    self?.refreshDevices()
                }
            }
        }
    }

    func copyInstallCommand() {
        let command = "curl -fsSL https://raw.githubusercontent.com/jotx19/cinema-engine/main/install.sh | bash"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
    }

    func stop() {
        controller?.stop(exitProcess: false)
        controller = nil
        running = false
        starting = false
        timer?.cancel()
        timer = nil
        peakL = 0
        peakR = 0
    }

    func setMix(_ parameter: MixParameter, _ value: Double) {
        config.setMix(parameter, value)
        selectedPreset = config.preset
        pushLive()
    }

    func applyPreset(_ name: String) {
        config.applyPreset(name)
        selectedPreset = config.preset
        pushLive()
    }

    private func pushLive() {
        guard let controller else {
            try? config.save()
            return
        }
        controller.applyLive(config, ramp: true)
        refreshSnapshot()
    }

    private func startPolling() {
        timer?.cancel()
        timer = Timer.publish(every: 0.08, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.controller?.tick()
                self?.refreshSnapshot()
            }
    }

    private func refreshSnapshot() {
        guard let snapshot = controller?.snapshot else { return }
        config = snapshot.config
        selectedPreset = snapshot.config.preset
        inputName = snapshot.inputName
        outputName = snapshot.outputName
        hrtfLabel = snapshot.hrtfLabel
        peakL = snapshot.peakL
        peakR = snapshot.peakR
        running = snapshot.running
    }

    private nonisolated static func runCommand(_ launchPath: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

private enum DeviceIconsSort {
    static func rank(_ name: String) -> Int {
        let lower = name.lowercased()
        if lower.contains("airpods") { return 0 }
        if lower.contains("beats") { return 1 }
        if lower.contains("macbook") || lower.contains("built-in") { return 2 }
        return 10
    }
}

extension EngineModel {
    fileprivate static func isHiddenOutput(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("cadevice")
            || lower.contains("aggregate")
            || lower.contains("multi-output")
            || lower == "cinema-engine"
            || lower.hasPrefix("cinema-engine")
    }
}

