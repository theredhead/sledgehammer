# Trust me, I know what I’m doing

A standalone native Swift/AppKit macOS prototype. Drop one app onto the utility’s icon in Finder or the Dock, or into its window. Inspect the selected app, then choose:

- **Lift quarantine**: remove download quarantine throughout that app without launching it. Disabled when no quarantine is present.
- **Trust this app**: remove quarantine if present, then request a normal macOS launch. This is explicit approval to run that app now. It also works when quarantine is already clear.
- **Cancel**: make no changes.

Nothing launches merely because an app is dropped. This is a convenience tool, not a malware scanner or a guarantee of trust. It never changes global Gatekeeper policy, repairs or re-signs targets, requests administrator privileges, or clears unrelated attributes. The product does not call private override APIs or hand the user off to Settings.

The complete workflow was tested on a fresh disposable, locally compiled AppKit fixture: seven quarantine attributes removed by the production code, two successful normal macOS launches verified by marker writes, signature intact, unrelated metadata preserved, Gatekeeper enabled before and after. No separate exception API was necessary for this fixture. This observation is not a guarantee for every app or macOS policy.

## Build and test

Requires macOS 13+ and Xcode command-line tools. Run `./scripts/build.sh`. The local, ad hoc signed Apple Silicon app is written to `outputs/Trust Me.app` on the development host. Open `Package.swift` in Xcode to develop. For tests, run `CLANG_MODULE_CACHE_PATH="$PWD/work/cache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/work/cache" swift test --disable-sandbox`.

## Code style

Readability takes priority over compactness. The checked-in `.swift-format` uses four-space indentation, a 110-column target, one statement per line, and preserves useful existing line breaks. Methods are separated by blank lines. Explicit returns and straightforward loops are retained where written.

Run `./scripts/format.sh` to format Swift sources, tests, scripts, and Package.swift. Run `./scripts/lint.sh` to check formatting and the selected SwiftLint rules without modifying files. The formatter comes from the selected Xcode toolchain (`xcrun swift-format`). Install SwiftLint with `brew install swiftlint`; version 0.65.1 was used for this pass.

SwiftLint uses an explicit small rule list in `.swiftlint.yml`: duplicate conditions, duplicate cases and dictionary keys, forced casts and forced tries, unused closure parameters and optional bindings, IBInspectable validity, and extra whitespace immediately inside opening braces. Orphaned documentation and comments separated from their declarations by a blank line are also checked. Declaration documentation uses `///` immediately above its declaration, with the separating blank line before the documentation; implementation notes use `//` beside the statements they explain. Layout is primarily handled by swift-format. Naming, method-length, and complexity limits are not enforced in this first configuration; adjust the rules after reviewing the result.

## Prototype limits

Only intact signed apps (including ad hoc signed apps) are supported. Quarantine on the app folder and its contents is handled in one approval. Unsigned apps are refused because a destroyed signature can be reported as unsigned. Traversal never follows symbolic links; quarantined hard-linked files are refused to avoid modifying files outside the selected app. All removal targets are opened and validated before writing. If removal or verification fails, the tool attempts to restore the original quarantine values and reports if restoration is incomplete. Inspection skips symbolic links and rejects a symlinked selected path. Unreadable contents cause refusal.

Inspection repeats after confirmation and checks the bundle’s filesystem identity. Removal uses an open directory descriptor. This reduces accidental replacement risk but does not provide an atomic snapshot of a bundle against a malicious process concurrently modifying its contents. Further hardening and review are needed before public distribution.

The Dock/Finder document-open handler is declared for `com.apple.application-bundle`; the window also accepts file URL drops. The handler requires exactly one app and leads to the same explicit confirmation. Finder/Dock drag behavior and first-launch UI still require manual validation on a normal desktop session.

## Research and observations

See `outputs/behavior-check.txt` and `outputs/Prototype notes.md`. No downloaded or real user apps were modified or launched. A separate LaunchServices probe launched only our own locally compiled harmless fixture after quarantine removal; the quarantined control did not produce a launch marker. Twelve automated tests cover recursive and nested-only removal, intact signatures after removal, preserving unrelated metadata and apps, hard-link protection, external symlink protection, replacement refusal, damaged signatures before and after review, quarantine restoration after a simulated partial failure, and preparing both quarantined and already-clear apps to open.

## Visual and distribution direction

The original icon uses a rounded toy-like hammer, warm amber handle, dark blue background, and a green deliberate-approval check. It refers playfully to the title without reproducing a TV still, performer, weapon, or show logo. The working title may need a naming/trademark review before release.

Plan: free direct download, optional donation link later, no payment integration. Before release: Developer ID signing and hardened runtime for this utility, notarization and stapling, clean-machine launch testing, Intel/universal build verification, accessibility and large-app inspection testing, and hostile-concurrency review. This build is local-only and not notarized.
