#if os(macOS)
import AppKit
import SwiftUI

struct ShareSheet: View {
    let items: [Any]
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 20) {
            Text("Share this page").font(Theme.book(24))
            if let image = items.first as? NSImage {
                Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 400)
            }
            NativeShareButton(items: items).frame(width: 140, height: 32)
            Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 400)
        .background(PaperBackground())
    }
}

private struct NativeShareButton: NSViewRepresentable {
    let items: [Any]
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Share…", target: context.coordinator, action: #selector(Coordinator.share(_:)))
        button.bezelStyle = .rounded
        return button
    }
    func updateNSView(_ button: NSButton, context: Context) { context.coordinator.items = items }
    final class Coordinator: NSObject {
        var items: [Any] = []
        private var picker: NSSharingServicePicker?
        @objc func share(_ sender: NSButton) {
            let picker = NSSharingServicePicker(items: items)
            self.picker = picker
            picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}
#endif
