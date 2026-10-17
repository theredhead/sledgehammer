import AppKit
import UniformTypeIdentifiers

/// Accepts file URL drops and passes them to the shared inspection workflow.
final class DropView: NSView {
    var onDrop: (([URL]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls =
            sender.draggingPasteboard.readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        onDrop?(urls)
        return !urls.isEmpty
    }
}

/// Presents app inspection and performs only the action explicitly approved by the user.
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var review: Review?
    let details = NSTextField(
        wrappingLabelWithString:
            "Drop an app here, or onto this utility’s icon in Finder or the Dock without opening it first.")
    let approve = NSButton(title: "Review app…", target: nil, action: nil)
    var busy = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu()
        let item = NSMenuItem()
        menu.addItem(item)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Trust Me", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu
        NSApp.mainMenu = menu
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 490),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Trust me, I know what I’m doing"
        let drop = DropView(frame: window.contentView!.bounds)
        window.contentView = drop
        drop.onDrop = { [weak self] in self?.receive($0) }
        let heading = NSTextField(wrappingLabelWithString: "Trust me, I know what I’m doing")
        heading.font = .systemFont(ofSize: 25, weight: .bold)
        let subtitle = NSTextField(
            wrappingLabelWithString:
                "The catchphrase of Inspector Sledge Hammer in the 1980s TV series Sledge Hammer!")
        subtitle.textColor = .secondaryLabelColor
        let appIcon = NSImageView()
        appIcon.image = NSImage(named: NSImage.applicationIconName)
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.setAccessibilityLabel("Trust Me app icon")
        NSLayoutConstraint.activate([
            appIcon.widthAnchor.constraint(equalToConstant: 64),
            appIcon.heightAnchor.constraint(equalToConstant: 64),
        ])
        let titleStack = NSStackView(views: [heading, subtitle])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 7
        let header = NSStackView(views: [appIcon, titleStack])
        header.orientation = .horizontal
        header.alignment = .top
        header.spacing = 16
        details.font = .systemFont(ofSize: 13)
        details.isSelectable = true
        let choose = NSButton(title: "Choose an app…", target: self, action: #selector(pick))
        approve.target = self
        approve.action = #selector(confirm)
        approve.isEnabled = false
        approve.bezelStyle = .rounded
        let footer = NSTextField(
            wrappingLabelWithString:
                "Removes download quarantine with your approval. Not a malware scanner or a guarantee of trust."
        )
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [header, details, choose, approve, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        drop.addSubview(stack)
        NSLayoutConstraint.activate([
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            heading.widthAnchor.constraint(equalTo: titleStack.widthAnchor),
            subtitle.widthAnchor.constraint(equalTo: titleStack.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: drop.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: drop.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: drop.topAnchor, constant: 28),
        ])
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ application: NSApplication, open urls: [URL]) { receive(urls) }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Inspects one app from either a window drop or a Finder/Dock open event, then presents its review.
    func receive(_ urls: [URL]) {
        guard !busy else { return }
        review = nil
        approve.isEnabled = false
        guard urls.count == 1 else {
            details.stringValue = "Choose exactly one app at a time."
            return
        }
        busy = true
        details.stringValue = "Inspecting app and signature…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Quarantine.inspect(urls[0]) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success(let value):
                    self.review = value
                    self.details.stringValue =
                        "\(value.name)\n\(value.url.path)\n\n\(value.signature)\n\nDownload quarantine: \(value.entries.isEmpty ? "not present; nothing to remove" : "present")"
                    self.approve.isEnabled = true
                    self.confirm()
                case .failure(let error): self.details.stringValue = error.localizedDescription
                }
                self.window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    @objc func pick() {
        guard !busy else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { receive([url]) }
    }

    /// Presents the reviewed app’s actions with Cancel as the default; dropping alone makes no changes.
    @objc func confirm() {
        guard !busy, let selected = review else { return }
        let alert = NSAlert()
        alert.messageText = "Review \(selected.name)"
        alert.informativeText =
            "\(selected.url.path)\n\n\(selected.signature)\nDownload quarantine: \(selected.entries.isEmpty ? "not present" : "present")\n\nLift quarantine removes download warning metadata without opening the app.\n\nTrust this app removes quarantine where needed, then opens this app through macOS. Only choose it if you trust the app’s source and want to run it now."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        let lift = alert.addButton(withTitle: "Lift quarantine")
        lift.isEnabled = !selected.entries.isEmpty
        alert.addButton(withTitle: "Trust this app")
        let response = alert.runModal()
        if response == .alertThirdButtonReturn {
            allowAndOpen(selected)
            return
        }
        guard response == .alertSecondButtonReturn else { return }
        busy = true
        approve.isEnabled = false
        review = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Quarantine.approve(selected) }
            DispatchQueue.main.async {
                self.busy = false
                switch result {
                case .success:
                    self.details.stringValue =
                        "Quarantine removed from \(selected.name).\n\(selected.url.path)\n\nQuarantine has been removed throughout this app. The app has not been opened."
                case .failure(let error): self.details.stringValue = error.localizedDescription
                }
            }
        }
    }

    /// Clears quarantine and requests a normal macOS launch after explicit approval to run this app.
    func allowAndOpen(_ selected: Review) {
        busy = true
        approve.isEnabled = false
        review = nil
        details.stringValue = "Preparing \(selected.name) to open…"
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try Quarantine.prepareToOpen(selected) }
            DispatchQueue.main.async {
                switch result {
                case .failure(let error):
                    self.busy = false
                    self.details.stringValue = error.localizedDescription
                case .success:
                    self.details.stringValue = "Opening \(selected.name)…"
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.promptsUserIfNeeded = true
                    configuration.allowsRunningApplicationSubstitution = false
                    configuration.addsToRecentItems = false
                    NSWorkspace.shared.openApplication(at: selected.url, configuration: configuration) {
                        running, error in
                        DispatchQueue.main.async {
                            self.busy = false
                            if running != nil {
                                self.details.stringValue =
                                    "\(selected.name) opened successfully.\n\(selected.url.path)\n\nYou can open this copy normally in Finder."
                            } else {
                                self.details.stringValue =
                                    "Quarantine is cleared, but macOS could not open \(selected.name).\n\n\(error?.localizedDescription ?? "The system did not return a running app.")"
                                let failure = NSAlert()
                                failure.messageText = "macOS could not open \(selected.name)"
                                failure.informativeText =
                                    error?.localizedDescription ?? "The system did not return a running app."
                                failure.addButton(withTitle: "OK")
                                failure.runModal()
                            }
                        }
                    }
                }
            }
        }
    }

}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
