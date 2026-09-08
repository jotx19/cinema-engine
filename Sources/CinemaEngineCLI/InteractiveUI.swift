import Darwin
import Foundation
import AudioEngine

enum ANSI {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let cyan = "\u{001B}[36m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let magenta = "\u{001B}[35m"
    static let white = "\u{001B}[37m"
    static let inverse = "\u{001B}[7m"
    static let clear = "\u{001B}[H\u{001B}[2J"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    static let altOn = "\u{001B}[?1049h"
    static let altOff = "\u{001B}[?1049l"
}

final class TerminalMode {
    private var original = termios()
    private var originalFlags: Int32 = 0
    private var active = false

    func enter() {
        guard isatty(STDIN_FILENO) != 0 else { return }
        tcgetattr(STDIN_FILENO, &original)
        var raw = original
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG)
        raw.c_iflag &= ~tcflag_t(IXON)
        tcsetattr(STDIN_FILENO, TCSANOW, &raw)
        originalFlags = fcntl(STDIN_FILENO, F_GETFL)
        _ = fcntl(STDIN_FILENO, F_SETFL, originalFlags | O_NONBLOCK)
        fputs(ANSI.altOn + ANSI.hideCursor, stdout)
        fflush(stdout)
        active = true
    }

    func leave() {
        guard active else { return }
        _ = fcntl(STDIN_FILENO, F_SETFL, originalFlags)
        tcsetattr(STDIN_FILENO, TCSANOW, &original)
        fputs(ANSI.showCursor + ANSI.altOff, stdout)
        fflush(stdout)
        active = false
    }
}

final class InteractiveUI {
    private let controller: AudioEngineController
    private let terminal = TerminalMode()
    private var selected = MixParameter.bass
    private var stdinSource: DispatchSourceRead?
    private var drawTimer: DispatchSourceTimer?

    init(controller: AudioEngineController) {
        self.controller = controller
    }

    func run() {
        terminal.enter()
        controller.willExit = { [weak self] in
            self?.teardown()
            self?.terminal.leave()
        }

        let input = DispatchSource.makeReadSource(fileDescriptor: STDIN_FILENO, queue: .main)
        input.setEventHandler { [weak self] in
            self?.readKeys()
        }
        input.resume()
        stdinSource = input

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: 0.08)
        timer.setEventHandler { [weak self] in
            self?.controller.tick()
            self?.draw()
        }
        timer.resume()
        drawTimer = timer

        draw()
        RunLoop.main.run()
    }

    private func teardown() {
        drawTimer?.cancel()
        stdinSource?.cancel()
        drawTimer = nil
        stdinSource = nil
    }

    private func readKeys() {
        var buffer = [UInt8](repeating: 0, count: 32)
        let count = read(STDIN_FILENO, &buffer, buffer.count)
        guard count > 0 else { return }
        var i = 0
        while i < count {
            let byte = buffer[i]
            if byte == 3 || byte == 4 || byte == 113 || byte == 81 {
                controller.shutdown()
                return
            }
            if byte == 27, i + 2 < count, buffer[i + 1] == 91 {
                switch buffer[i + 2] {
                case 65: moveSelection(-1) // up
                case 66: moveSelection(1)  // down
                case 67: nudge(5)          // right
                case 68: nudge(-5)         // left
                default: break
                }
                i += 3
                continue
            }
            switch byte {
            case 91: nudge(-1) // [
            case 93: nudge(1)  // ]
            case 49: applyPreset("theatre")
            case 50: applyPreset("reference")
            case 51: applyPreset("night")
            default: break
            }
            i += 1
        }
        draw()
    }

    private func moveSelection(_ delta: Int) {
        let all = MixParameter.allCases
        let index = (selected.rawValue + delta + all.count) % all.count
        selected = all[index]
    }

    private func nudge(_ delta: Double) {
        var config = controller.liveConfig
        config.nudge(selected, by: delta)
        controller.applyLive(config, ramp: false)
    }

    private func applyPreset(_ name: String) {
        var config = controller.liveConfig
        config.applyPreset(name)
        controller.applyLive(config, ramp: true)
    }

    private func draw() {
        let snap = controller.snapshot
        let config = snap.config
        var lines: [String] = []

        lines.append(ANSI.clear)
        lines.append("")
        lines.append(
            "  \(ANSI.bold)\(ANSI.cyan)cinema-engine\(ANSI.reset)  " +
            "\(ANSI.green)● live\(ANSI.reset)  " +
            "\(ANSI.dim)\(config.preset)\(ANSI.reset)"
        )
        lines.append("  \(ANSI.dim)system audio in  ·  cinema DSP  ·  \(snap.outputName)\(ANSI.reset)")
        lines.append("")

        for parameter in MixParameter.allCases {
            lines.append(knobRow(parameter, config: config))
        }

        lines.append("")
        lines.append(
            "  \(ANSI.dim)L\(ANSI.reset) \(meter(snap.peakL, width: 16, color: ANSI.cyan))    " +
            "\(ANSI.dim)R\(ANSI.reset) \(meter(snap.peakR, width: 16, color: ANSI.magenta))"
        )
        lines.append("  \(ANSI.dim)\(snap.inputName)  →  \(snap.outputName)\(ANSI.reset)")
        lines.append("")
        lines.append("  \(ANSI.dim)↑↓ select   ←→ ±5   [ ] ±1   1 theatre  2 reference  3 night\(ANSI.reset)")
        lines.append("  \(ANSI.dim)q / ctrl-c  stop  (audio back to normal)\(ANSI.reset)")
        lines.append("")

        fputs(lines.joined(separator: "\n") + "\n", stdout)
        fflush(stdout)
    }

    private func knobRow(_ parameter: MixParameter, config: EngineConfig) -> String {
        let value = parameter.value(in: config)
        let active = parameter == selected
        let marker = active ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let name = parameter.label.padding(toLength: 10, withPad: " ", startingAt: 0)
        let nameText = active ? "\(ANSI.bold)\(ANSI.cyan)\(name)\(ANSI.reset)" : "\(ANSI.dim)\(name)\(ANSI.reset)"
        let bar = meter(Float(value / 100.0), width: 24, color: active ? ANSI.cyan : ANSI.dim)
        let number = String(format: "%3.0f", value)
        let numberText = active ? "\(ANSI.bold)\(number)\(ANSI.reset)" : "\(ANSI.dim)\(number)\(ANSI.reset)"
        return "  \(marker) \(nameText) \(bar)  \(numberText)"
    }

    private func meter(_ peak: Float, width: Int, color: String) -> String {
        let clamped = min(1, max(0, peak))
        let filled = min(width, Int((clamped * Float(width)).rounded(.down)))
        let body = String(repeating: "█", count: filled) + String(repeating: "░", count: width - filled)
        return "\(color)\(body)\(ANSI.reset)"
    }
}
