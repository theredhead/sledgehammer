# Prototype 0.1

Native AppKit utility with Finder/Dock document-open support and window drops. Explicit review and cancel-first confirmation. “Lift quarantine” does not launch; “Trust this app” removes quarantine and requests a normal macOS launch after the user’s explicit approval. No global policy changes.

Built and core-tested on macOS 26.6.2, Apple Silicon. Twelve XCTest cases passed after adding recursive removal. Disposable, locally ad hoc signed bundles were used; the test executable was copied from the system `true` tool and never launched. Tests preserve a second app’s quarantine and an unrelated attribute on the selected app.

The separate behavior probe removed only a disposable app’s outer quarantine attribute, then confirmed signature verification still passed. `spctl --status` reported assessments enabled before and after. Explicit `spctl --assess` returned “internal error in Code Signing subsystem” both before and after. This is inconclusive for launch behavior and does not establish a bypass. A subsequent LaunchServices launch test outside the development sandbox used our own locally compiled harmless AppKit fixture: the quarantined copy produced no launch marker, while the quarantine-cleared copy launched and wrote its marker. Both open requests returned zero. This demonstrates the intended launch behavior for this fixture on this host, not every app or every security policy. See launch-probe.txt. No separate Gatekeeper exception was created.

Apple’s documentation describes quarantine as part of first-open checks, with code signatures, notarization, malware and revocation checks also relevant. Clearing quarantine is not notarization, does not repair a signature, and cannot guarantee execution. Apple’s supported manual flow is Privacy & Security → Open Anyway when available.

Sources researched October 15, 2026:

- [Safely open apps on your Mac](https://support.apple.com/en-au/102445)
- [Test a Developer ID-signed app](https://help.apple.com/xcode/mac/current/en.lproj/dev1cc22a95c.html)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

Unsigned apps are refused. Quarantine within the selected app is removed along with outer quarantine after one explicit approval. All targets are pinned using file descriptors, path components are opened without following symlinks, and quarantined hard-linked files are refused. If a change fails, original quarantine values are restored where possible, with an explicit warning if restoration fails. Broken signatures are refused. Read README.md in the project for known concurrency and distribution limitations. Finder/Dock drops and the full visual flow await manual desktop validation; document type declarations alone do not prove that workflow.


Latest complete-workflow test: see combined-launch-probe.txt. A freshly signed disposable app had seven quarantine attributes. The production prepareToOpen method removed them, then NSWorkspace launched the app normally twice; both launches wrote the expected marker. Signature verification passed, an unrelated attribute survived, and Gatekeeper assessments stayed enabled. No private override call, Settings interaction, or system-wide policy change was required.

Direct override API experiments remain documented in Gatekeeper investigation.md as historical investigation. Their failure does not imply that the complete remove-quarantine-and-launch workflow fails. The current product uses that tested complete workflow for “Trust this app.”
