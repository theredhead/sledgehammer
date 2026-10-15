import AppKit
// This executable is solely a development harness for our disposable fixture.
let expected = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("work/launch-probe/CombinedProbe.app").standardizedFileURL
let selected = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
guard selected == expected else { fatalError("Only the named disposable fixture is allowed") }
do {
    let review = try Quarantine.inspect(selected)
    print("Quarantined items before: \(review.entries.count)")
    try Quarantine.prepareToOpen(review)
    print("Quarantined items after: \(try Quarantine.inspect(selected).entries.count)")
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.promptsUserIfNeeded = true
    configuration.allowsRunningApplicationSubstitution = false
    configuration.addsToRecentItems = false
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: selected, configuration: configuration) { running, error in
        if let running {
            print("Normal macOS launch succeeded; PID \(running.processIdentifier)")
            exit(0)
        }
        print("Normal macOS launch failed: \(String(describing: error))")
        exit(1)
    }
    RunLoop.main.run()
} catch {
    print("Preparation failed: \(error.localizedDescription)")
    exit(1)
}
