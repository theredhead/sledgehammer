import Foundation
import Security
import Darwin

struct Review {
    let url: URL
    let name: String
    let signature: String
    let quarantine: Data?
    let device: dev_t
    let inode: ino_t
}
struct Refusal: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
enum Quarantine {
    static let attribute = "com.apple.quarantine"
    static func metadata(_ url: URL) throws -> stat {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { throw Refusal("Cannot read this app: \(String(cString: strerror(errno)))") }
        guard info.st_mode & S_IFMT == S_IFDIR else { throw Refusal("Choose an app folder, not an alias or symbolic link.") }
        return info
    }
    static func read(_ path: String) throws -> Data? {
        let size = getxattr(path, attribute, nil, 0, 0, XATTR_NOFOLLOW)
        if size < 0 {
            if errno == ENOATTR { return nil }
            throw Refusal("Cannot inspect quarantine: \(String(cString: strerror(errno)))")
        }
        var bytes = [UInt8](repeating: 0, count: size)
        let count = getxattr(path, attribute, &bytes, size, 0, XATTR_NOFOLLOW)
        guard count == size else { throw Refusal("Quarantine changed during inspection. Drop the app again.") }
        return Data(bytes)
    }
    static func signature(_ url: URL) throws -> String {
        var code: SecStaticCode?
        let created = SecStaticCodeCreateWithPath(url as CFURL, [], &code)
        guard created == errSecSuccess, let code else { throw Refusal("This is not a readable code bundle.") }
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
        let result = SecStaticCodeCheckValidity(code, flags, nil)
        if result == errSecCSUnsigned { throw Refusal("No valid signature found. This conservative prototype requires an intact signature, including an ad hoc signature. Ask the developer for a signed build.") }
        guard result == errSecSuccess else {
            throw Refusal("Signature validation failed (\(result)). This tool will not override a broken signature.")
        }
        return "Signature intact — this does not establish trust or notarization"
    }
    static func inspect(_ input: URL) throws -> Review {
        let url = input.standardizedFileURL
        guard url.isFileURL, url.pathExtension.lowercased() == "app" else { throw Refusal("Drop one macOS .app bundle.") }
        guard url.resolvingSymlinksInPath().path == url.path else { throw Refusal("Move the app to a location without symbolic links first.") }
        let info = try metadata(url)
        guard let bundle = Bundle(url: url), bundle.executableURL != nil,
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL" else { throw Refusal("This folder is not a complete macOS app bundle.") }
        // Inspection never follows symlinks or modifies nested content.
        var traversalError: Error?
        guard let entries = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [], errorHandler: { _, error in traversalError = error; return false }) else { throw Refusal("Cannot inspect app contents.") }
        for case let child as URL in entries {
            let values = try child.resourceValues(forKeys: [.isSymbolicLinkKey])
            if values.isSymbolicLink == true { entries.skipDescendants(); continue }
            if try read(child.path) != nil { throw Refusal("Quarantine also exists inside this app. This prototype only supports quarantine on the outer app folder. No changes were made.") }
        }
        if let traversalError { throw traversalError }
        return Review(url: url, name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent,
                      signature: try signature(url), quarantine: try read(url.path), device: info.st_dev, inode: info.st_ino)
    }
    static func approve(_ review: Review) throws {
        let current = try inspect(review.url)
        guard current.device == review.device, current.inode == review.inode,
              current.quarantine == review.quarantine, current.signature == review.signature else { throw Refusal("The app changed. Drop it again to review it.") }
        guard review.quarantine != nil else { throw Refusal("This app has no outer quarantine attribute to remove.") }
        let fd = open(review.url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw Refusal("Cannot access this app. No administrator access will be requested.") }
        defer { close(fd) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_dev == review.device, info.st_ino == review.inode else { throw Refusal("The selected app was replaced. Drop it again.") }
        guard fremovexattr(fd, attribute, 0) == 0 else { throw Refusal("Could not remove quarantine: \(String(cString: strerror(errno))). Try moving your own app to a writable folder.") }
        guard try read(review.url.path) == nil else { throw Refusal("Could not verify removal. Inspect the app again.") }
    }
}
