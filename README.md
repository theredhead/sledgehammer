# Trust me, I know what I’m doing

A standalone native Swift/AppKit macOS prototype. Drop one app onto the utility’s icon in Finder or the Dock, or into its window. Inspect the path and signature status, then explicitly confirm removing the selected app’s outer download-quarantine attribute. The target app is never launched.

This is a convenience tool, not a malware scanner, a trust endorsement, or a guarantee that macOS will open an app. It never changes global Gatekeeper policy, repairs or re-signs targets, requests administrator privileges, or clears other attributes.

## Build and test

Requires macOS 13+ and Xcode command-line tools. Run `./scripts/build.sh`. The local, ad hoc signed Apple Silicon app is written to `outputs/Trust Me.app` on the development host. Open `Package.swift` in Xcode to develop. For tests, run `CLANG_MODULE_CACHE_PATH="$PWD/work/cache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/cache" swift test --disable-sandbox`.

## Prototype limits

Only intact signed apps (including ad hoc signed apps) with quarantine exclusively on the outer bundle are supported. Unsigned apps are refused because a destroyed signature can be reported as unsigned. Nested quarantine is refused without mutation. No recursive clearing is performed. Inspection skips symbolic links and rejects a symlinked selected path. Unreadable contents cause refusal.

Inspection repeats after confirmation and checks the bundle’s filesystem identity. Removal uses an open directory descriptor. This reduces accidental replacement risk but does not provide an atomic snapshot of a bundle against a malicious process concurrently modifying its contents. Further hardening and review are needed before public distribution.

The Dock/Finder document-open handler is declared for `com.apple.application-bundle`; the window also accepts file URL drops. The handler requires exactly one app and leads to the same explicit confirmation. Finder/Dock drag behavior and first-launch UI still require manual validation on a normal desktop session.

## Research and observations

See `outputs/behavior-check.txt` and `outputs/Prototype notes.md`. No downloaded or real user apps were modified, and no test app was launched. The five automated tests cover selected-only removal, preserving unrelated metadata, nested quarantine refusal, replacement refusal, symlink refusal, and damaged-signature refusal (some checks share one test).

## Visual and distribution direction

The original icon uses a rounded toy-like hammer, warm amber handle, dark blue background, and a green deliberate-approval check. It refers playfully to the title without reproducing a TV still, performer, weapon, or show logo. The working title may need a naming/trademark review before release.

Plan: free direct download, optional donation link later, no payment integration. Before release: Developer ID signing and hardened runtime for this utility, notarization and stapling, clean-machine launch testing, Intel/universal build verification, accessibility and large-app inspection testing, and hostile-concurrency review. This build is local-only and not notarized.
