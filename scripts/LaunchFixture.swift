import AppKit
final class Delegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let marker = Bundle.main.bundleURL.deletingPathExtension().appendingPathExtension("launched")
        try? Data("Disposable locally compiled fixture launched.\n".utf8).write(to: marker)
        NSApplication.shared.terminate(nil)
    }
}
let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
