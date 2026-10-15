# Prototype 0.1

Native AppKit utility with Finder/Dock document-open support and window drops. Explicit review and cancel-first confirmation. No automatic launch and no global policy changes.

Built and core-tested on macOS 26.6.2, Apple Silicon. Five XCTest cases passed. Disposable, locally ad hoc signed bundles were used; the test executable was copied from the system `true` tool and never launched. Tests preserve a second app’s quarantine and an unrelated attribute on the selected app.

The separate behavior probe removed only a disposable app’s outer quarantine attribute, then confirmed signature verification still passed. `spctl --status` reported assessments enabled before and after. Explicit `spctl --assess` returned “internal error in Code Signing subsystem” both before and after. This is inconclusive for launch behavior and does not establish a bypass. No LaunchServices first-launch experiment has been performed.

Apple’s documentation describes quarantine as part of first-open checks, with code signatures, notarization, malware and revocation checks also relevant. Clearing quarantine is not notarization, does not repair a signature, and cannot guarantee execution. Apple’s supported manual flow is Privacy & Security → Open Anyway when available.

Sources researched October 15, 2026:

- [Safely open apps on your Mac](https://support.apple.com/en-au/102445)
- [Test a Developer ID-signed app](https://help.apple.com/xcode/mac/current/en.lproj/dev1cc22a95c.html)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

Initial scope deliberately refuses unsigned apps and nested quarantine. Broken signatures are refused. Read README.md in the project for known concurrency and distribution limitations. Finder/Dock drops and the full visual flow await manual desktop validation; document type declarations alone do not prove that workflow.
