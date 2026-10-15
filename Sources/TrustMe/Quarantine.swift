import Foundation
import Security
import Darwin

struct QuarantineEntry: Equatable {
    let path: String
    let device: dev_t
    let inode: ino_t
    let value: Data
}
struct Review {
    let url: URL
    let name: String
    let signature: String
    let quarantine: Data?
    let device: dev_t
    let inode: ino_t
    let entries: [QuarantineEntry]
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
        let original = input.standardizedFileURL
        let url = original.resolvingSymlinksInPath()
        guard url.isFileURL, url.pathExtension.lowercased() == "app" else { throw Refusal("Drop one macOS .app bundle.") }
        guard original.resolvingSymlinksInPath().path == original.path else { throw Refusal("Move the app to a location without symbolic links first.") }
        let info = try metadata(url)
        guard let bundle = Bundle(url: url), bundle.executableURL != nil,
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL" else { throw Refusal("This folder is not a complete macOS app bundle.") }
        // Symlinks are never followed. Hard-linked quarantined files are refused:
        // changing their metadata could also change a file outside the chosen app.
        var quarantined: [QuarantineEntry] = []
        func record(_ child: URL, relative: String) throws {
            var metadata = stat()
            guard lstat(child.path, &metadata) == 0 else { throw Refusal("Could not inspect every part of this app. Nothing was changed.") }
            guard let value = try read(child.path) else { return }
            let kind = metadata.st_mode & S_IFMT
            guard kind == S_IFDIR || (kind == S_IFREG && metadata.st_nlink == 1) else {
                throw Refusal("This app contains linked files that cannot be changed safely. Nothing was changed.")
            }
            quarantined.append(QuarantineEntry(path: relative, device: metadata.st_dev, inode: metadata.st_ino, value: value))
        }
        try record(url, relative: "")
        func walk(_ directory: URL, relative: String) throws {
            for name in try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted() {
                let child = directory.appendingPathComponent(name)
                let path = relative.isEmpty ? name : relative + "/" + name
                var metadata = stat()
                guard lstat(child.path, &metadata) == 0 else { throw Refusal("Could not inspect every part of this app. Nothing was changed.") }
                try record(child, relative: path)
                if metadata.st_mode & S_IFMT == S_IFDIR { try walk(child, relative: path) }
            }
        }
        try walk(url, relative: "")
        return Review(url: url, name: bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? url.deletingPathExtension().lastPathComponent,
                      signature: try signature(url), quarantine: try read(url.path), device: info.st_dev, inode: info.st_ino, entries: quarantined.sorted { $0.path < $1.path })
    }
    // Open every path component relative to a pinned directory; never follow links.
    static func openEntry(_ path: String, root: Int32) throws -> Int32 {
        var fd = dup(root)
        guard fd >= 0 else { throw Refusal("Cannot access all of this app. Nothing was changed.") }
        for part in path.split(separator: "/") {
            let next = openat(fd, String(part), O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
            close(fd)
            guard next >= 0 else { throw Refusal("The app changed or a file cannot be accessed. Drop it again.") }
            fd = next
        }
        return fd
    }
    static func prepareToOpen(_ review: Review) throws {
        let current = try inspect(review.url)
        guard current.device == review.device, current.inode == review.inode,
              current.entries == review.entries, current.signature == review.signature else {
            throw Refusal("The app changed. Drop it again before allowing it to open.")
        }
        if !review.entries.isEmpty { try approve(review) }
    }
    static func removeAttribute(_ fd: Int32) throws {
        guard fremovexattr(fd, attribute, 0) == 0 else { throw Refusal("Some files could not be changed. Move your app to a writable folder and try again.") }
    }
    static func approve(_ review: Review, removal: (Int32) throws -> Void = removeAttribute) throws {
        let current = try inspect(review.url)
        guard current.device == review.device, current.inode == review.inode,
              current.entries == review.entries, current.signature == review.signature else { throw Refusal("The app changed. Drop it again to review it.") }
        guard !review.entries.isEmpty else { throw Refusal("This app has no download quarantine to remove.") }
        let root = open(review.url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard root >= 0 else { throw Refusal("Cannot access this app. No administrator access will be requested.") }
        defer { close(root) }
        var info = stat()
        guard fstat(root, &info) == 0, info.st_dev == review.device, info.st_ino == review.inode else { throw Refusal("The selected app was replaced. Drop it again.") }
        var handles: [(Int32, QuarantineEntry)] = []
        defer { for (fd, _) in handles { close(fd) } }
        // Pin and validate all targets before the first write.
        for entry in review.entries {
            let fd = try openEntry(entry.path, root: root)
            handles.append((fd, entry))
            var metadata = stat()
            guard fstat(fd, &metadata) == 0, metadata.st_dev == entry.device, metadata.st_ino == entry.inode,
                  (metadata.st_mode & S_IFMT == S_IFDIR || (metadata.st_mode & S_IFMT == S_IFREG && metadata.st_nlink == 1)) else { throw Refusal("The app changed. Drop it again to review it.") }
            var value = [UInt8](repeating: 0, count: entry.value.count)
            let count = fgetxattr(fd, attribute, &value, value.count, 0, 0)
            guard count == entry.value.count, Data(value) == entry.value else { throw Refusal("The app changed. Drop it again to review it.") }
        }
        _ = try signature(review.url)
        var changed: [(Int32, QuarantineEntry)] = []
        do {
            for (fd, entry) in handles {
                try removal(fd)
                changed.append((fd, entry))
            }
            let after = try inspect(review.url)
            guard after.device == review.device, after.inode == review.inode, after.entries.isEmpty else { throw Refusal("The app changed while processing. Drop it again.") }
        } catch {
            var restored = true
            for (fd, entry) in changed.reversed() {
                let result = entry.value.withUnsafeBytes { fsetxattr(fd, attribute, $0.baseAddress, $0.count, 0, 0) }
                if result != 0 { restored = false }
            }
            throw Refusal(restored ? "\(error.localizedDescription) Any quarantine removed by this attempt was restored." : "Could not finish or fully restore this app’s quarantine. Some changes remain. Download a fresh copy before trying again.")
        }
    }
}
