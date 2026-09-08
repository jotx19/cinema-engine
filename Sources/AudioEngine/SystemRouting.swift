import CoreAudio
import Foundation

public struct RoutingSnapshot: Codable, Sendable {
    public var previousOutputUID: String
    public var previousOutputName: String
    public var previousInputUID: String?
    public var previousInputName: String?
    public var blackHoleUID: String
    public var blackHoleName: String

    public func save() {
        try? CinemaPaths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: CinemaPaths.routingFile, options: .atomic)
    }

    public static func load() -> RoutingSnapshot? {
        guard let data = try? Data(contentsOf: CinemaPaths.routingFile) else { return nil }
        return try? JSONDecoder().decode(RoutingSnapshot.self, from: data)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: CinemaPaths.routingFile)
    }
}

public enum SystemRouting {
    /// Point macOS system output at BlackHole so every app is captured, while
    /// cinema-engine plays to the user's real headphones/speakers.
    public static func engage(blackHole: AudioDeviceInfo, playback: AudioDeviceInfo) throws {
        let current = try DeviceManager.defaultOutputDevice()
        let previous: AudioDeviceInfo
        if DeviceManager.isVirtualLoopback(current), let saved = RoutingSnapshot.load() {
            previous = (try? DeviceManager.find(query: saved.previousOutputUID, role: .output))
                ?? (try? DeviceManager.find(query: saved.previousOutputName, role: .output))
                ?? playback
        } else if DeviceManager.isVirtualLoopback(current) {
            previous = playback
        } else {
            previous = current
        }

        let previousInput = try? DeviceManager.defaultInputDevice()

        RoutingSnapshot(
            previousOutputUID: previous.uid,
            previousOutputName: previous.name,
            previousInputUID: previousInput?.uid,
            previousInputName: previousInput?.name,
            blackHoleUID: blackHole.uid,
            blackHoleName: blackHole.name
        ).save()

        if current.id != blackHole.id {
            let loopback = (try? DeviceManager.blackHole(role: .output)) ?? blackHole
            try DeviceManager.setDefaultOutputDevice(loopback)
        }
        Thread.sleep(forTimeInterval: 0.2)
    }

    @discardableResult
    public static func restore() -> String? {
        guard let snapshot = RoutingSnapshot.load() else { return nil }
        let restored = (try? DeviceManager.find(query: snapshot.previousOutputUID, role: .output))
            ?? (try? DeviceManager.find(query: snapshot.previousOutputName, role: .output))
        if let restored {
            try? DeviceManager.setDefaultOutputDevice(restored)
        }
        if let inputUID = snapshot.previousInputUID,
           let input = (try? DeviceManager.find(query: inputUID, role: .input))
            ?? (snapshot.previousInputName.flatMap { try? DeviceManager.find(query: $0, role: .input) })
        {
            try? DeviceManager.setDefaultInputDevice(input)
        }
        RoutingSnapshot.clear()
        return restored?.name ?? snapshot.previousOutputName
    }
}

public enum BlackHoleInstaller {
    private static let packageURLs = [
        "https://existential.audio/downloads/BlackHole2ch.v0.7.1.pkg",
        "https://github.com/ExistentialAudio/BlackHole/releases/download/v0.7.1/BlackHole2ch.v0.7.1.pkg"
    ]

    public static func isInstalled() -> Bool {
        (try? DeviceManager.blackHole(role: .input)) != nil
    }

    public static func install(usingShellCommand commandRunner: (String, [String]) throws -> Int32) throws {
        if isInstalled() { return }

        if let brew = which("brew") {
            let status = try commandRunner(brew, ["install", "--cask", "blackhole-2ch"])
            if status == 0, waitForDevice() != nil { return }
        }

        let pkg = FileManager.default.temporaryDirectory.appendingPathComponent("BlackHole2ch.pkg")
        var downloaded = false
        for url in packageURLs {
            let status = try commandRunner("/usr/bin/curl", ["-fsSL", "-o", pkg.path, url])
            if status == 0, FileManager.default.fileExists(atPath: pkg.path) {
                downloaded = true
                break
            }
        }
        guard downloaded else {
            throw EngineError.blackHoleInstallFailed
        }

        let installStatus = try commandRunner("/usr/bin/sudo", ["installer", "-pkg", pkg.path, "-target", "/"])
        _ = try? commandRunner("/usr/bin/killall", ["coreaudiod"])
        guard installStatus == 0 else {
            throw EngineError.blackHoleInstallFailed
        }
        guard waitForDevice() != nil else {
            throw EngineError.blackHoleMissing
        }
    }

    public static func waitForDevice(timeout: TimeInterval = 25) -> AudioDeviceInfo? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let device = try? DeviceManager.blackHole(role: .input) {
                return device
            }
            Thread.sleep(forTimeInterval: 0.4)
        }
        return nil
    }

    public static func which(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (path?.isEmpty == false) ? path : nil
        } catch {
            return nil
        }
    }
}
