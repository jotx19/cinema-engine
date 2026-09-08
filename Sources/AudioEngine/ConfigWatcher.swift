import Darwin
import Foundation

public enum RuntimeControl {
    public static func writePid() throws {
        try CinemaPaths.ensureDirectory()
        let pid = ProcessInfo.processInfo.processIdentifier
        try "\(pid)\n".write(to: CinemaPaths.pidFile, atomically: true, encoding: .utf8)
    }

    public static func clearPid() {
        try? FileManager.default.removeItem(at: CinemaPaths.pidFile)
        try? FileManager.default.removeItem(at: CinemaPaths.stateFile)
    }

    public static func runningPid() -> pid_t? {
        guard
            let raw = try? String(contentsOf: CinemaPaths.pidFile, encoding: .utf8),
            let pid = pid_t(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
            pid > 0
        else {
            return nil
        }
        if pid == ProcessInfo.processInfo.processIdentifier {
            return pid
        }
        if kill(pid, 0) == 0 {
            return pid
        }
        if errno == EPERM {
            return pid
        }
        return nil
    }

    @discardableResult
    public static func sendStop() -> pid_t? {
        guard let pid = runningPid() else { return nil }
        kill(pid, SIGTERM)
        return pid
    }
}

public final class ConfigWatcher {
    private let queue = DispatchQueue(label: "org.cinema-engine.config-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var onChange: ((EngineConfig) -> Void)?
    private var debounceWork: DispatchWorkItem?

    public init() {}

    deinit {
        stop()
    }

    public func start(onChange: @escaping (EngineConfig) -> Void) {
        self.onChange = onChange
        queue.async { [weak self] in
            self?.register()
        }
    }

    public func stop() {
        queue.sync {
            source?.cancel()
            source = nil
            if fileDescriptor >= 0 {
                close(fileDescriptor)
                fileDescriptor = -1
            }
        }
    }

    private func register() {
        source?.cancel()
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }

        try? CinemaPaths.ensureDirectory()
        if !FileManager.default.fileExists(atPath: CinemaPaths.configFile.path) {
            try? EngineConfig.theatre.save()
        }

        fileDescriptor = open(CinemaPaths.configFile.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleChange()
        }
        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }
        self.source = source
        source.resume()
    }

    private func handleChange() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let config = EngineConfig.load()
            self.onChange?(config)
            self.register()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
