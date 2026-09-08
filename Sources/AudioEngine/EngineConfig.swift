import Foundation

public enum CinemaPaths {
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cinema-engine", isDirectory: true)
    }

    public static var configFile: URL {
        directory.appendingPathComponent("config.json")
    }

    public static var stateFile: URL {
        directory.appendingPathComponent("state.json")
    }

    public static var pidFile: URL {
        directory.appendingPathComponent("cinema-engine.pid")
    }

    public static var routingFile: URL {
        directory.appendingPathComponent("routing.json")
    }

    public static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}

public struct EngineConfig: Codable, Equatable, Sendable {
    public var preset: String
    public var bass: Double
    public var width: Double
    public var dialogue: Double
    public var room: Double
    public var inputDevice: String
    public var outputDevice: String

    enum CodingKeys: String, CodingKey {
        case preset, bass, width, dialogue, room
        case inputDevice = "input_device"
        case outputDevice = "output_device"
    }

    public static let theatre = EngineConfig(
        preset: "theatre",
        bass: 70,
        width: 80,
        dialogue: 60,
        room: 40,
        inputDevice: "auto",
        outputDevice: "auto"
    )

    public static let reference = EngineConfig(
        preset: "reference",
        bass: 45,
        width: 40,
        dialogue: 50,
        room: 15,
        inputDevice: "auto",
        outputDevice: "auto"
    )

    public static let night = EngineConfig(
        preset: "night",
        bass: 35,
        width: 55,
        dialogue: 75,
        room: 22,
        inputDevice: "auto",
        outputDevice: "auto"
    )

    public static func named(_ name: String) -> EngineConfig? {
        switch name.lowercased() {
        case "theatre", "theater", "cinema":
            return .theatre
        case "reference", "flat":
            return .reference
        case "night":
            return .night
        default:
            return nil
        }
    }

    public func clamped() -> EngineConfig {
        var copy = self
        copy.bass = Self.clamp(bass)
        copy.width = Self.clamp(width)
        copy.dialogue = Self.clamp(dialogue)
        copy.room = Self.clamp(room)
        return copy
    }

    public static func clamp(_ value: Double) -> Double {
        min(100, max(0, value))
    }

    public static func load(from url: URL = CinemaPaths.configFile) -> EngineConfig {
        guard let data = try? Data(contentsOf: url) else {
            return .theatre
        }
        let decoder = JSONDecoder()
        return ((try? decoder.decode(EngineConfig.self, from: data)) ?? .theatre).clamped()
    }

    public func save(to url: URL = CinemaPaths.configFile) throws {
        try CinemaPaths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(clamped())
        try data.write(to: url, options: .atomic)
    }

    public func applying(parameter: String, value: String) throws -> EngineConfig {
        var next = self
        let key = parameter.lowercased()
        switch key {
        case "preset":
            guard var presetConfig = EngineConfig.named(value) else {
                throw ConfigError.unknownPreset(value)
            }
            presetConfig.inputDevice = inputDevice
            presetConfig.outputDevice = outputDevice
            return presetConfig
        case "bass":
            next.bass = try Self.parseUnit(value)
        case "width":
            next.width = try Self.parseUnit(value)
        case "dialogue", "dialog":
            next.dialogue = try Self.parseUnit(value)
        case "room", "reverb":
            next.room = try Self.parseUnit(value)
        case "input_device", "input":
            next.inputDevice = value
        case "output_device", "output":
            next.outputDevice = value
        default:
            throw ConfigError.unknownParameter(parameter)
        }
        return next.clamped()
    }

    private static func parseUnit(_ value: String) throws -> Double {
        guard let number = Double(value) else {
            throw ConfigError.invalidValue(value)
        }
        return clamp(number)
    }

    public mutating func setMix(_ parameter: MixParameter, _ value: Double) {
        switch parameter {
        case .bass: bass = Self.clamp(value)
        case .width: width = Self.clamp(value)
        case .dialogue: dialogue = Self.clamp(value)
        case .room: room = Self.clamp(value)
        }
        syncPresetName()
    }

    public mutating func nudge(_ parameter: MixParameter, by delta: Double) {
        setMix(parameter, parameter.value(in: self) + delta)
    }

    public mutating func applyPreset(_ name: String) {
        guard let presetConfig = EngineConfig.named(name) else { return }
        bass = presetConfig.bass
        width = presetConfig.width
        dialogue = presetConfig.dialogue
        room = presetConfig.room
        preset = presetConfig.preset
    }

    public mutating func syncPresetName() {
        if self.mixEquals(.theatre) {
            preset = "theatre"
        } else if self.mixEquals(.reference) {
            preset = "reference"
        } else if self.mixEquals(.night) {
            preset = "night"
        } else {
            preset = "custom"
        }
    }

    private func mixEquals(_ other: EngineConfig) -> Bool {
        bass == other.bass && width == other.width && dialogue == other.dialogue && room == other.room
    }
}

public enum MixParameter: Int, CaseIterable {
    case bass, width, dialogue, room

    public var label: String {
        switch self {
        case .bass: return "bass"
        case .width: return "width"
        case .dialogue: return "dialogue"
        case .room: return "room"
        }
    }

    public func value(in config: EngineConfig) -> Double {
        switch self {
        case .bass: return config.bass
        case .width: return config.width
        case .dialogue: return config.dialogue
        case .room: return config.room
        }
    }
}

public enum ConfigError: Error, CustomStringConvertible {
    case unknownParameter(String)
    case unknownPreset(String)
    case invalidValue(String)

    public var description: String {
        switch self {
        case .unknownParameter(let name):
            return "Unknown parameter '\(name)'. Use bass, width, dialogue, room, preset, input_device, or output_device."
        case .unknownPreset(let name):
            return "Unknown preset '\(name)'. Use theatre, reference, or night."
        case .invalidValue(let value):
            return "Invalid value '\(value)'. Expected a number from 0 to 100."
        }
    }
}

public struct RuntimeState: Codable, Sendable {
    public var active: Bool
    public var pid: Int32
    public var preset: String
    public var inputDevice: String
    public var outputDevice: String
    public var bass: Double
    public var width: Double
    public var dialogue: Double
    public var room: Double
    public var peakL: Double
    public var peakR: Double
    public var sampleRate: Double
    public var bufferFrames: Int
    public var hrtfEnabled: Bool

    public init(
        active: Bool,
        pid: Int32,
        config: EngineConfig,
        peakL: Double,
        peakR: Double,
        sampleRate: Double,
        bufferFrames: Int,
        hrtfEnabled: Bool
    ) {
        self.active = active
        self.pid = pid
        self.preset = config.preset
        self.inputDevice = config.inputDevice
        self.outputDevice = config.outputDevice
        self.bass = config.bass
        self.width = config.width
        self.dialogue = config.dialogue
        self.room = config.room
        self.peakL = peakL
        self.peakR = peakR
        self.sampleRate = sampleRate
        self.bufferFrames = bufferFrames
        self.hrtfEnabled = hrtfEnabled
    }

    public static func load() -> RuntimeState? {
        guard let data = try? Data(contentsOf: CinemaPaths.stateFile) else {
            return nil
        }
        return try? JSONDecoder().decode(RuntimeState.self, from: data)
    }

    public func save() {
        try? CinemaPaths.ensureDirectory()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: CinemaPaths.stateFile, options: .atomic)
    }
}
