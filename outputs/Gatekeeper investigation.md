# Direct per-app Gatekeeper approval: historical investigation

**Later complete-workflow result:** production quarantine removal followed by two normal macOS launches succeeded on a fresh disposable fixture. Gatekeeper remained enabled. See combined-launch-probe.txt. The failed API-only experiments below were not a test of that complete workflow.

Host: macOS 26.6.2, Apple Silicon. Only our locally compiled disposable fixture was targeted. Global Gatekeeper settings were never changed.

## Actual tests

- `spctl --add --hash` returns exit 4: “This operation is no longer supported.” The local manual says rule database modifications are unsupported as of macOS 15.
- The older Security `SecAssessmentUpdate` function was called with a requirement restricted to the exact disposable executable code hash. It returned false with error -60008 (`errAuthorizationInternal`), both inside and outside the development sandbox. No rule was added.
- Read-only inspection of System Settings’ SecurityPrivacyExtension shows that it imports `SPExecutionPolicy` and invokes `addGatekeeperOverrideForPersistentIdentifier:error:`. Its Apple signature grants private entitlements including `com.apple.private.syspolicy.gatekeeper-override`, `com.apple.private.syspolicy.gatekeeper-block-bypass`, and `com.apple.private.syspolicy.gatekeeper.settings-management`.
- A separate Objective-C probe loaded the native SystemPolicy framework and read the last rejection record. Before attempting any change, it resolved the record’s bookmark and required an exact match to our disposable Quarantined.app. The probe then invoked that native per-app override operation with the record’s persistent identifier.
- Within the development sandbox, the service lookup was denied. Outside it, the actual method returned false with `SPErrorDomain` code 4. The exact meaning of that code is not established by public documentation. It did not report success, and no saved approval is claimed.

A further native method, `addGatekeeperUserIntent:error:`, returned true for the disposable app. A subsequent normal LaunchServices request still produced no launch marker while its `0083;...` quarantine remained present. Registering user intent therefore did not provide a working approval route in this test.

These findings establish failed direct implementation attempts, not a proof that every possible approach is impossible. The private entitlement on Apple’s component is strong evidence of a restricted operation. Merely adding a private entitlement to our own ad hoc signature would not grant Apple’s authorization and has not been attempted.

## Current prototype

The final prototype uses the complete workflow: inspect and validate, remove quarantine throughout the selected app, then use NSWorkspace to launch normally only after explicit “Trust this app” approval. “Lift quarantine” performs removal without launching. Twelve core tests pass. No private override API or Settings handoff is used in the product. Actual launch errors are reported without claiming success.

The desired runnable outcome was demonstrated for the fresh disposable fixture with this combined workflow. It did not require a separate override call. These tests do not guarantee that every app will run; broken signatures remain a refusal condition.

Test source: scripts/NativeOverrideProbe.m and scripts/AssessmentProbe.c. Test outputs: native-override-probe.txt and assessment-probe.txt. Sources were researched, not copied into the product’s approval path.

Apple references:

- [Safely open apps on your Mac](https://support.apple.com/en-us/102445): the documented Open Anyway flow saves an exception.
- [Archived Code Signing Tasks](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html): describes the older spctl --add mechanism. Current local manual and actual tests take precedence over this archived guidance.
- [Apple Security source: SecAssessment](https://github.com/apple-oss-distributions/Security/blob/main/OSX/libsecurity_codesigning/lib/SecAssessment.cpp): implementation background for older Security assessment operations; not a promise of availability on current macOS.
