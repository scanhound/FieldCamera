# Validation report

Performed on Windows, October 13, 2026.

- PASS: Xcode project parsed as OpenStep syntax; all checked object references resolve.
- PASS: All three Swift source files are included by the target source build phase.
- PASS: Shared scheme is valid XML and references the application target.
- PASS: Info.plist parses and includes Camera, Microphone and Photos permission strings.
- PASS: Workflow YAML parses; manual trigger, macOS runner, unsigned build and IPA artifact paths are consistent.
- REVIEWED: Capture queue, permission flow, exact format selection, recording callbacks, PCM RMS meters, album save and retention logic.

PASS: GitHub Actions run #2 compiled the simulator app, archived the ARM64 iPhone app, and packaged/uploaded the unsigned IPA using Xcode 16.4 / SDK 18.5.

Evidence: https://github.com/scanhound/FieldCamera/actions/runs/38488033999
Commit: dc0474ec0a10e1881738e0e27787dbca1ccbc01c

PASS: Downloaded artifact SHA-256 matches GitHub: bf6c9148bb8050f7bf2e3b8fcd526a8221e74a8a87db65882fb0fbf6722cac21.
PASS: IPA ZIP integrity, iphoneos platform, ARM64 Mach-O executable, bundle identifier, and permission strings checked.

First run failed because audioSettings is macOS-only. Corrected to read iOS-supplied PCM buffers with integer/float and interleaved/planar handling. Run #2 passed. Non-fatal SDK/concurrency deprecation warnings remain; Swift 5 mode is used.

NOT RUN: AltStore signing/installation or any iPhone hardware/Photos/audio acceptance check.
Compilation and packaging are verified; runtime functionality is not yet verified. Follow README.md for the first build and device checks.
