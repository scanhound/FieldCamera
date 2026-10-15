# Continuous monitoring prototype — October 14, 2026

This update extends the existing landscape-capable Field Camera project. It is source code, not an installable app. The original project and earlier IPAs remain untouched.

## What changed
- Optional AVAudioEngine direct input → mixer → output monitoring with an explicitly shared AVAudioSession. Monitoring stays active when Tests closes and when recording starts/stops.
- Select an available microphone by actual port name/UID. iOS must confirm that source before monitoring starts. The DJI receiver may appear as USB audio; a name alone does not prove its signal is correct.
- Headphone-only start check, initial gain 10%, maximum gain 25%, manual Mute/Stop, and automatic monitor stop on route changes, interruptions, engine configuration changes, backgrounding, or media-services reset. Route transitions can still produce a brief hardware-level transient before notification; test at low volume.
- No scheduled buffer queue: direct engine graph avoids software backlog. Displayed latency is an iOS-reported estimate, not measured acoustic latency. AirPods Bluetooth delay may be unsuitable for live voice monitoring.
- The Tests panel is disabled during recording/saving. Source/session changes briefly pause idle capture; capture resumes afterward. Movie output, capture queue, local retention and Photos save logic are retained. Shared session ownership is a material change requiring device regression testing.
- BLE diagnostic: 20-second scan, user-selected peripheral connection, discovery of accessible services/characteristics, readable values, notifications/indications, raw hex, timestamped test markers, and shareable rolling log (1,500 lines maximum). No proprietary writes or decoded record/wheel mappings. System HID traffic may be inaccessible to CoreBluetooth.

## First iPhone test
1. Connect the DJI mic receiver and AirPods. Select AirPods in Control Center. Open Field Camera → Tests.
2. Tap Start monitor once to activate/refresh available sources if needed. Choose the DJI receiver source, then Start monitor. Read the confirmed input/output names. Keep volume low.
3. Speak and listen. Close Tests. Confirm MONITOR ON remains visible. Record and stop three short clips, speaking throughout. Confirm sound remains in AirPods and saved clips have the correct microphone sound, no dropouts, and acceptable sync.
4. Repeat with monitoring off. Compare recorded audio quality. Test a longer clip before using this for field work. If monitoring disrupts capture, keep monitoring off and retain the original build until corrected.
5. At low volume, disconnect AirPods: confirm monitoring stops and does not continue through the speaker. Reconnect and restart manually. Test mic unplugging, app background/foreground, and an interruption. Recording behavior and recovery require hands-on checks.
6. For OM6: Tests → Scan → select the device you can identify as OM6 → Connect. Mark record, press the physical button several times; mark wheel, turn in both directions. Share diagnostic log. Repeat with DJI Mimo closed if no connection is possible. No events does not prove the wheel cannot work; it means this diagnostic did not see accessible data.

## Free Windows build/install route
Existing public repository: https://github.com/scanhound/FieldCamera
Replace its source/project files with this update, preserving .github/workflows. GitHub Actions → Build Field Camera unsigned IPA → Run workflow. Its macOS runner compiles simulator and device targets and packages an unsigned IPA. Standard public-repository runners are free: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
After a successful run, download FieldCamera-unsigned-IPA, extract the IPA and install/re-sign using AltStore Classic with AltServer on Windows: https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
A free Apple account requires periodic refresh (7-day provisioning). Apple account entry stays with you. The source ZIP cannot be installed directly; older IPAs do not contain this update.

## Verification boundary
Verified here: permission plist and scheme XML parse; six Swift sources exist and are included in the source build phase; project IDs are unique and references resolve; workflow is retained; source changes reviewed and ZIP generated.
Not verified: Swift compilation, updated IPA packaging, installation, simultaneous camera/engine microphone access, audible DJI-to-AirPods monitoring, latency, recording quality/sync, route fallback timing, interruption recovery, OM6 identity/access/events or any control decoding.
No Xcode or Swift compiler is installed on this Windows machine. No updated GitHub build has been run in this session. Earlier build results belong to older source and do not validate this update.
