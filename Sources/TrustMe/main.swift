import AppKit
import UniformTypeIdentifiers

final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { fatalError() }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        onDrop?(urls); return !urls.isEmpty
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var review: Review?
    let details = NSTextField(wrappingLabelWithString: "Drop an app onto this utility’s icon in Finder or the Dock.\nYou can also drop an app into this window.")
    let approve = NSButton(title: "Review removal…", target: nil, action: nil)
    var busy = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let item = NSMenuItem(); menu.addItem(item)
        let appMenu = NSMenu(); appMenu.addItem(withTitle: "Quit Trust Me", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"); item.submenu = appMenu; NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 580, height: 490), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Trust me, I know what I’m doing"
        let drop = DropView(frame: window.contentView!.bounds); window.contentView = drop
        drop.onDrop = { [weak self] in self?.receive($0) }
        let icon = NSTextField(labelWithString: "✋"); icon.font = .systemFont(ofSize: 46)
        let heading = NSTextField(labelWithString: "Your app. Your decision."); heading.font = .systemFont(ofSize: 25, weight: .bold)
        let subtitle = NSTextField(wrappingLabelWithString: "Drop onto this utility’s icon in Finder or the Dock.\nNo need to open it first. Dropping into this window works too.")
        subtitle.textColor = .secondaryLabelColor
        details.font = .monospacedSystemFont(ofSize: 12, weight: .regular); details.isSelectable = true
        let choose = NSButton(title: "Choose an app…", target: self, action: #selector(pick))
        approve.target = self; approve.action = #selector(confirm); approve.isEnabled = false; approve.bezelStyle = .rounded
        let footer = NSTextField(wrappingLabelWithString: "Not a malware scanner or a guarantee of trust. Nothing opens automatically. System-wide Gatekeeper settings stay unchanged."); footer.font = .systemFont(ofSize: 11); footer.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [icon, heading, subtitle, details, choose, approve, footer]); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 18; stack.translatesAutoresizingMaskIntoConstraints = false
        drop.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: drop.leadingAnchor, constant: 32), stack.trailingAnchor.constraint(equalTo: drop.trailingAnchor, constant: -32), stack.topAnchor.constraint(equalTo: drop.topAnchor, constant: 28)])
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func application(_ application: NSApplication, open urls: [URL]) { receive(urls) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func receive(_ urls: [URL]) {
        guard !busy else { return }
        review = nil; approve.isEnabled = false
        guard urls.count == 1 else { details.stringValue = "Choose exactly one app at a time."; return }
        busy = true; details.stringValue = "Inspecting app and signature…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Quarantine.inspect(urls[0]) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let value):
                    self.review = value
                    self.details.stringValue = "\(value.name)\n\(value.url.path)\n\n\(value.signature)\n\nDownload quarantine: \(value.quarantine == nil ? "not present; nothing to remove" : "present")"
                    self.approve.isEnabled = value.quarantine != nil
                case .failure(let error): self.details.stringValue = error.localizedDescription
                }
                self.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    @objc func pick() {
        guard !busy else { return }
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowedContentTypes = [.applicationBundle]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { receive([url]) }
    }
    @objc func confirm() {
        guard !busy, let selected = review else { return }
        let alert = NSAlert(); alert.messageText = "Remove quarantine from \(selected.name)?"
        alert.informativeText = "\(selected.url.path)\n\nYou are removing this app’s download warning metadata. This does not verify its safety or notarization, repair it, or guarantee macOS will allow it to open. Only continue if you trust its source.\n\nThe app will not be launched."
        alert.alertStyle = .warning; alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Remove quarantine")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        busy = true; approve.isEnabled = false; review = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Quarantine.approve(selected) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success: self.details.stringValue = "Quarantine removed from \(selected.name).\n\(selected.url.path)\n\nThe app has not been opened. macOS may still block it."
                case .failure(let error): self.details.stringValue = error.localizedDescription
                }
            }
        }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
