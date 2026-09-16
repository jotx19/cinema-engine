import AppKit
import AudioEngine
import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var model: EngineModel

    var body: some View {
        Group {
            if model.blackHoleInstalled {
                mixerPanel
            } else {
                setupPanel
            }
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            model.refreshDevices()
        }
    }

    private var brandMark: some View {
        Group {
            if let url = Bundle.module.url(forResource: "BrandMark", withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
            }
        }
    }

    private var setupPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Cinema Engine")

            HStack(spacing: 10) {
                brandMark
                Text("Setup required")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("BlackHole required")
                        .font(.system(size: 13, weight: .semibold))
                }

                Text("Cinema Engine needs the BlackHole audio driver to capture Mac audio. Install it once, then Start.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    model.installBlackHole()
                } label: {
                    HStack {
                        if model.installingBlackHole {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(model.installingBlackHole ? "Installing…" : "Install BlackHole")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.accentColor))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(model.installingBlackHole)

                Button {
                    model.copyInstallCommand()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                        Text("Copy install.sh command")
                            .font(.system(size: 12))
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                if let error = model.errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)

            divider
            quitRow
        }
        .padding(.vertical, 10)
    }

    private var mixerPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Cinema Engine")

            HStack(spacing: 10) {
                brandMark
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Button {
                        model.start()
                    } label: {
                        Text(model.starting ? "…" : "Start")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(model.running ? Color.primary.opacity(0.08) : Color.accentColor)
                            )
                            .foregroundStyle(model.running ? Color.secondary : Color.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(model.running || model.starting)

                    Button {
                        model.stop()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(model.running ? Color.primary.opacity(0.14) : Color.primary.opacity(0.06))
                            )
                            .foregroundStyle(model.running ? Color.primary : Color.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.running || model.starting)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            NativeSliderRow(
                systemImage: "speaker.wave.2.fill",
                value: Binding(
                    get: { model.config.bass / 100 },
                    set: { model.setMix(.bass, $0 * 100) }
                )
            )
            .padding(.bottom, 8)

            divider

            sectionHeader("Output")
            ForEach(model.outputDevices, id: \.uid) { device in
                Button {
                    model.selectOutput(device)
                } label: {
                    DeviceRow(
                        title: device.name,
                        systemImage: DeviceIcons.symbol(for: device.name),
                        selected: model.outputName == device.name
                            || (!model.running && (
                                model.config.outputDevice == device.name
                                    || (model.config.outputDevice == "auto" && device.name == model.preferredOutputName)
                            ))
                    )
                }
                .buttonStyle(.plain)
            }
            if model.outputDevices.isEmpty {
                DeviceRow(
                    title: model.outputName,
                    systemImage: DeviceIcons.symbol(for: model.outputName),
                    selected: true
                )
            }

            divider

            sectionHeader("Preset")
            ForEach(["theatre", "reference", "night"], id: \.self) { preset in
                CheckRow(
                    title: preset.capitalized,
                    systemImage: presetIcon(preset),
                    checked: model.selectedPreset == preset
                ) {
                    model.applyPreset(preset)
                }
            }

            divider

            sectionHeader("Mix")
            VStack(spacing: 14) {
                MixValueRow(title: "Width", systemImage: "arrow.left.and.right", value: binding(for: .width))
                MixValueRow(title: "Dialogue", systemImage: "person.wave.2", value: binding(for: .dialogue))
                MixValueRow(title: "Room", systemImage: "building.columns", value: binding(for: .room))
            }
            .padding(.horizontal, 14)
            .padding(.top, 2)
            .padding(.bottom, 4)

            divider

            sectionHeader("Spatial Audio")
            DeviceRow(
                title: model.running ? "HRTF · \(model.hrtfLabel)" : "Not Available",
                systemImage: "airpodspro",
                selected: false,
                dimmed: !model.running
            )

            if let error = model.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
            }

            divider
            quitRow
        }
        .padding(.vertical, 10)
    }

    private var quitRow: some View {
        Button {
            model.stop()
            NSApplication.shared.terminate(nil)
        } label: {
            Text("Quit Cinema Engine…")
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 4)
    }

    private var divider: some View {
        Divider()
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
    }

    private func presetIcon(_ preset: String) -> String {
        switch preset {
        case "theatre": return "theatermasks"
        case "reference": return "tuningfork"
        case "night": return "moon.zzz"
        default: return "slider.horizontal.3"
        }
    }

    private func binding(for parameter: MixParameter) -> Binding<Double> {
        Binding(
            get: { parameter.value(in: model.config) },
            set: { model.setMix(parameter, $0) }
        )
    }
}

private enum DeviceIcons {
    static func symbol(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpodspro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("homepod") { return "homepod.and.homepodmini" }
        if lower.contains("blackhole") { return "cable.connector" }
        if lower.contains("multi-output") || lower.contains("aggregate") { return "hifispeaker.and.appletv" }
        if lower.contains("macbook") || lower.contains("built-in") || lower.contains("speakers") {
            return "laptopcomputer"
        }
        if lower.contains("bluetooth") || lower.contains("beats") { return "beats.headphones" }
        return "hifispeaker"
    }
}

private struct NativeSliderRow: View {
    let systemImage: String
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Slider(value: $value, in: 0...1)
                .controlSize(.small)
                .tint(.accentColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }
}

private struct DeviceRow: View {
    let title: String
    let systemImage: String
    var selected: Bool = false
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .foregroundStyle(dimmed ? .tertiary : .primary)
                .frame(width: 22)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(dimmed ? .tertiary : .primary)
                .lineLimit(1)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(selected ? Color.primary.opacity(0.12) : Color.clear)
        )
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .opacity(dimmed ? 0.7 : 1)
    }
}

private struct CheckRow: View {
    let title: String
    let systemImage: String
    let checked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
                if checked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(checked ? Color.primary.opacity(0.12) : Color.clear)
            )
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MixValueRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.85))
                    .frame(width: 20, alignment: .center)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text("\(Int(value.rounded()))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)
            }

            RulerSlider(value: $value, range: 0...100)
        }
    }
}

private struct RulerSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    private let thumbWidth: CGFloat = 10
    private let thumbHeight: CGFloat = 18
    private let trackHeight: CGFloat = 14
    private let tickCount = 48

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
            let x = progress * max(width - thumbWidth, 0)

            ZStack(alignment: .leading) {
                // Tick ruler track
                HStack(spacing: 0) {
                    ForEach(0..<tickCount, id: \.self) { index in
                        Capsule()
                            .fill(Color.primary.opacity(tickOpacity(for: index, progress: progress)))
                            .frame(width: 1.5, height: tickHeight(for: index))
                        if index < tickCount - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: trackHeight)
                .padding(.horizontal, thumbWidth / 2)

                // Thumb
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.95),
                                Color.white.opacity(0.72)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.black.opacity(0.18), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 1.5, y: 0.5)
                    .frame(width: thumbWidth, height: thumbHeight)
                    .offset(x: x)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        update(at: drag.location.x, width: width)
                    }
            )
        }
        .frame(height: thumbHeight)
        .accessibilityValue(Text("\(Int(value.rounded()))"))
    }

    private func tickHeight(for index: Int) -> CGFloat {
        index % 6 == 0 ? 11 : (index % 3 == 0 ? 8 : 5)
    }

    private func tickOpacity(for index: Int, progress: CGFloat) -> Double {
        let tickProgress = Double(index) / Double(max(tickCount - 1, 1))
        if tickProgress <= Double(progress) {
            return index % 6 == 0 ? 0.55 : 0.38
        }
        return index % 6 == 0 ? 0.28 : 0.16
    }

    private func update(at locationX: CGFloat, width: CGFloat) {
        let usable = max(width - thumbWidth, 1)
        let clamped = min(max(locationX - thumbWidth / 2, 0), usable)
        let next = range.lowerBound + Double(clamped / usable) * (range.upperBound - range.lowerBound)
        value = next.rounded().clamped(to: range)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
