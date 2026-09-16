import SwiftUI
import AppKit

@main
struct CinemaEngineApp: App {
    @StateObject private var model = EngineModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(model)
        } label: {
            MenuBarLabel(running: model.running)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    let running: Bool

    var body: some View {
        Image(nsImage: menuBarImage)
            .renderingMode(.template)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
            .opacity(running ? 1.0 : 0.9)
            .accessibilityLabel("Cinema Engine")
    }

    private var menuBarImage: NSImage {
        if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            return image
        }
        let fallback = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Cinema Engine")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        fallback.isTemplate = true
        return fallback
    }
}
