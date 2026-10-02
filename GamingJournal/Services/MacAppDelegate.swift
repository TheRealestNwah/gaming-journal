#if os(macOS)
import AppKit
import OSLog

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.gamingjournal.GamingJournal", category: "Launch")
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.notice("Finished launch; windows: \(NSApplication.shared.windows.count)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
            for window in NSApplication.shared.windows {
                logger.notice("Window: \(window.title, privacy: .public); visible: \(window.isVisible); frame: \(NSStringFromRect(window.frame), privacy: .public)")
            }
        }
    }
}
#endif
