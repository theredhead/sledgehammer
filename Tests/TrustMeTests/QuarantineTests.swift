import XCTest
@testable import TrustMe
final class QuarantineTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws { root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func run(_ tool: String, _ args: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: tool); process.arguments = args; try process.run(); process.waitUntilExit(); XCTAssertEqual(process.terminationStatus, 0)
    }
    func fixture(_ name: String = "Disposable") throws -> URL {
        let app = root.appendingPathComponent("\(name).app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleExecutable": "Fixture", "CFBundlePackageType": "APPL", "CFBundleIdentifier": "local.disposable.fixture"]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: app.appendingPathComponent("Contents/Info.plist"))
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: app.appendingPathComponent("Contents/MacOS/Fixture").path)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;DisposableTest;", app.path])
        return app
    }
    func testOnlySelectedOuterAttributeRemoved() throws {
        let app = try fixture(); let other = try fixture("Other")
        try run("/usr/bin/xattr", ["-w", "local.keep", "preserved", app.path])
        let review = try Quarantine.inspect(app); XCTAssertNotNil(review.quarantine)
        try Quarantine.approve(review)
        XCTAssertNil(try Quarantine.read(app.path)); XCTAssertNotNil(try Quarantine.read(other.path))
        try run("/usr/bin/xattr", ["-p", "local.keep", app.path])
        XCTAssertNoThrow(try Quarantine.signature(app))
    }
    func testTamperedSignatureRefused() throws {
        let app = try fixture()
        try Data("tampered".utf8).write(to: app.appendingPathComponent("Contents/MacOS/Fixture"))
        XCTAssertThrowsError(try Quarantine.inspect(app)); XCTAssertNotNil(try Quarantine.read(app.path))
    }
    func testNestedQuarantineRemoved() throws {
        let app = try fixture()
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", app.appendingPathComponent("Contents/Info.plist").path])
        let review = try Quarantine.inspect(app)
        XCTAssertEqual(review.entries.count, 2)
        try Quarantine.approve(review)
        XCTAssertTrue(try Quarantine.inspect(app).entries.isEmpty)
        XCTAssertNoThrow(try Quarantine.signature(app))
    }
    func testReplacedAppRefused() throws {
        let app = try fixture(); let review = try Quarantine.inspect(app)
        try FileManager.default.moveItem(at: app, to: root.appendingPathComponent("Old.app"))
        _ = try fixture()
        XCTAssertThrowsError(try Quarantine.approve(review)); XCTAssertNotNil(try Quarantine.read(app.path))
    }
    func testSymlinkRefused() throws {
        let app = try fixture(); let link = root.appendingPathComponent("Link.app")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: app)
        XCTAssertThrowsError(try Quarantine.inspect(link))
    }
    func testNestedOnlyQuarantineRemoved() throws {
        let app = try fixture()
        try run("/usr/bin/xattr", ["-d", "com.apple.quarantine", app.path])
        let executable = app.appendingPathComponent("Contents/MacOS/Fixture")
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", executable.path])
        let review = try Quarantine.inspect(app)
        XCTAssertNil(review.quarantine)
        XCTAssertEqual(review.entries.count, 1)
        try Quarantine.approve(review)
        XCTAssertNil(try Quarantine.read(executable.path))
        XCTAssertNoThrow(try Quarantine.signature(app))
    }
    func testHardLinkCannotChangeOutsideFile() throws {
        let app = try fixture()
        let inside = app.appendingPathComponent("Contents/shared.txt")
        let outside = root.appendingPathComponent("Outside.txt")
        try Data("keep".utf8).write(to: outside)
        try FileManager.default.linkItem(at: outside, to: inside)
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", outside.path])
        XCTAssertThrowsError(try Quarantine.inspect(app))
        XCTAssertNotNil(try Quarantine.read(outside.path))
        XCTAssertNotNil(try Quarantine.read(app.path))
    }
    func testExternalSymlinkNeverFollowed() throws {
        let app = try fixture()
        let outside = root.appendingPathComponent("Outside.txt")
        try Data("keep".utf8).write(to: outside)
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", outside.path])
        try FileManager.default.createSymbolicLink(at: app.appendingPathComponent("Contents/Link"), withDestinationURL: outside)
        try run("/usr/bin/codesign", ["--force", "--sign", "-", app.path])
        if let review = try? Quarantine.inspect(app) { try Quarantine.approve(review) }
        XCTAssertNotNil(try Quarantine.read(outside.path))
    }
    func testTamperedAfterReviewRefused() throws {
        let app = try fixture()
        let review = try Quarantine.inspect(app)
        try Data("tampered".utf8).write(to: app.appendingPathComponent("Contents/MacOS/Fixture"))
        XCTAssertThrowsError(try Quarantine.approve(review))
        XCTAssertNotNil(try Quarantine.read(app.path))
    }

    func testPartialFailureRestoresQuarantine() throws {
        let app = try fixture()
        let child = app.appendingPathComponent("Contents/Info.plist")
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", child.path])
        let review = try Quarantine.inspect(app)
        var attempts = 0
        XCTAssertThrowsError(try Quarantine.approve(review, removal: { fd in
            attempts += 1
            if attempts == 2 { throw Refusal("Simulated write failure") }
            try Quarantine.removeAttribute(fd)
        }))
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(try Quarantine.inspect(app).entries, review.entries)
    }

    func testPrepareToOpenClearsAllQuarantine() throws {
        let app = try fixture()
        try run("/usr/bin/xattr", ["-w", "com.apple.quarantine", "0083;00000000;Test;", app.appendingPathComponent("Contents/MacOS/Fixture").path])
        try Quarantine.prepareToOpen(Quarantine.inspect(app))
        XCTAssertTrue(try Quarantine.inspect(app).entries.isEmpty)
    }
    func testPrepareAlreadyClearApp() throws {
        let app = try fixture()
        try run("/usr/bin/xattr", ["-d", "com.apple.quarantine", app.path])
        XCTAssertNoThrow(try Quarantine.prepareToOpen(Quarantine.inspect(app)))
        XCTAssertNoThrow(try Quarantine.signature(app))
    }

}
