import ArgumentParser
import AudioEngine
import Darwin
import Foundation

struct CinemaEngine: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "cinema-engine",
        abstract: "Cinema/theatre DSP chain for macOS system audio.",
        discussion: """
        Run `cinema-engine` (or `cinema-engine start` / `cinema-engine dev`) to
        process system audio live. Arrow keys change mix levels. q restores
        normal audio.
        """,
        version: "1.0.0",
        subcommands: [Setup.self, ListDevices.self, Start.self, Set.self, Status.self, Stop.self],
        defaultSubcommand: Start.self
    )
}

struct Setup: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Install BlackHole, write config, and prepare auto-routing. No Sound Settings steps."
    )

    func run() throws {
        try CinemaPaths.ensureDirectory()

        if BlackHoleInstaller.isInstalled() {
            print("BlackHole is already installed.")
        } else {
            print("Installing BlackHole 2ch (admin password may be required)...")
            do {
                try BlackHoleInstaller.install(usingShellCommand: runCommand)
                print("BlackHole installed.")
            } catch {
                fputs("error: \(error)\n", stderr)
                throw ExitCode.failure
            }
        }

        var config = FileManager.default.fileExists(atPath: CinemaPaths.configFile.path)
            ? EngineConfig.load()
            : .theatre
        if let input = try? DeviceManager.blackHole(role: .input) {
            config.inputDevice = input.name
        } else {
            config.inputDevice = "auto"
        }
        if let output = try? DeviceManager.resolveOutput(query: "auto") {
            config.outputDevice = output.name
        } else {
            config.outputDevice = "auto"
        }
        try config.save()
        print("Wrote \(CinemaPaths.configFile.path)")
        print("Playback device: \(config.outputDevice)")
        print("""

        Ready. You do not need to change System Settings > Sound.
        `cinema-engine` (or `cinema-engine start`) opens the live mixer.
        Arrow keys change levels. q restores normal audio.

          cinema-engine
        """)
    }
}

struct ListDevices: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list-devices",
        abstract: "List CoreAudio input and output devices."
    )

    func run() throws {
        print(try DeviceManager.formattedList())
    }
}

struct Start: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Run the live cinema engine (interactive). Audio returns to normal when you quit.",
        aliases: ["dev"]
    )

    @Option(help: "Input device name or UID. Default: auto (BlackHole).")
    var input: String?

    @Option(help: "Output device name or UID. Default: auto (current headphones/speakers).")
    var output: String?

    @Option(help: "Preset: theatre, reference, night.")
    var preset: String?

    @Flag(name: .customLong("no-hrtf"), help: "Disable HRTF convolution.")
    var noHrtf = false

    @Flag(name: .customLong("no-route"), help: "Do not change the system default output device.")
    var noRoute = false

    @Flag(help: "Plain status line instead of the interactive mixer.")
    var plain = false

    func run() throws {
        var config = EngineConfig.load()
        if let preset, var presetConfig = EngineConfig.named(preset) {
            presetConfig.inputDevice = config.inputDevice
            presetConfig.outputDevice = config.outputDevice
            config = presetConfig
        }
        if let input { config.inputDevice = input }
        if let output { config.outputDevice = output }

        let interactive = !plain && isatty(STDIN_FILENO) != 0 && isatty(STDOUT_FILENO) != 0
        let controller = AudioEngineController(
            config: config,
            hrtfEnabled: !noHrtf,
            autoRoute: !noRoute
        )
        do {
            try controller.run(interactive: interactive)
            if interactive {
                InteractiveUI(controller: controller).run()
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            throw ExitCode.failure
        }
    }
}

struct Set: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Update a live parameter in ~/.cinema-engine/config.json."
    )

    @Argument(help: "Parameter: bass, width, dialogue, room, preset, input_device, output_device.")
    var parameter: String

    @Argument(help: "Value. Levels are 0-100.")
    var value: String

    func run() throws {
        try CinemaPaths.ensureDirectory()
        let current = EngineConfig.load()
        do {
            let next = try current.applying(parameter: parameter, value: value)
            try next.save()
            print("Set \(parameter) = \(value)")
            print("Wrote \(CinemaPaths.configFile.path)")
            if RuntimeControl.runningPid() != nil {
                print("Running engine will pick this up within ~100 ms.")
            }
        } catch {
            fputs("error: \(error)\n", stderr)
            throw ExitCode.failure
        }
    }
}

struct Status: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Show whether cinema-engine is running and the current parameters."
    )

    func run() {
        let config = EngineConfig.load()
        if let pid = RuntimeControl.runningPid(), let state = RuntimeState.load(), state.active {
            print("status        : running (pid \(pid))")
            print("preset        : \(state.preset)")
            print("input         : \(state.inputDevice)")
            print("output        : \(state.outputDevice)")
            print("bass          : \(Int(state.bass))")
            print("width         : \(Int(state.width))")
            print("dialogue      : \(Int(state.dialogue))")
            print("room          : \(Int(state.room))")
            print("sample rate   : \(Int(state.sampleRate)) Hz")
            print("buffer frames : \(state.bufferFrames)")
            print("hrtf          : \(state.hrtfEnabled ? "on" : "off")")
        } else {
            print("status        : stopped")
            print("preset        : \(config.preset)")
            print("input         : \(config.inputDevice)")
            print("output        : \(config.outputDevice)")
            print("bass          : \(Int(config.bass))")
            print("width         : \(Int(config.width))")
            print("dialogue      : \(Int(config.dialogue))")
            print("room          : \(Int(config.room))")
        }
    }
}

struct Stop: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Stop the engine and restore normal system audio."
    )

    func run() {
        guard let pid = RuntimeControl.sendStop() else {
            if let restored = SystemRouting.restore() {
                print("cinema-engine was not running. Restored system output to \(restored).")
            } else {
                print("cinema-engine is not running.")
            }
            return
        }
        print("Sent SIGTERM to cinema-engine (pid \(pid)).")
        for _ in 0..<20 {
            if RuntimeControl.runningPid() == nil { break }
            usleep(100_000)
        }
        if RoutingSnapshot.load() != nil, let restored = SystemRouting.restore() {
            print("Restored system output to \(restored).")
        }
    }
}

func runCommand(_ executable: String, _ arguments: [String]) throws -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    var environment = ProcessInfo.processInfo.environment
    environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
    process.environment = environment
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}
