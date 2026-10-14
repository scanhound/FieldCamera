# Field Camera — Spot News Edition

Native iPhone camera project, version 0.1.0. Requires iOS 16 or later.

## What is delivered

- An actual `FieldCamera.xcodeproj` with a shared build scheme and SwiftUI/AVFoundation source. No paid dependencies, web wrapper, server, or analytics.
- Rear wide camera preview starts on launch after Camera and Microphone permission. Capture setup runs away from the main UI thread. First launch requires permission prompts; startup speed has not been measured.
- Explicit 1920×1080 camera format and fixed 30 fps frame duration. H.264 requested when supported; QuickTime `.mov` files with microphone sound. Hardware must support this format or the app reports an error.
- Zoom slider from 1× to the device limit, capped at 6×; digital zoom on the rear wide lens. Tap the picture to autofocus and set autoexposure at that point.
- Live microphone RMS meters in dBFS, one bar per delivered input channel. A mono input produces one bar; two bars do not promise independent stereo sources. No audio monitoring is configured.
- Record/stop button; portrait and landscape capture. Hold the phone in the desired orientation before pressing Record. The movie orientation stays fixed for that clip.
- Saves finished clips into Photos → Albums → FIELD CAMERA. Album lookup requires **Full Photos Access**; limited/denied access retains local files with a Save button.
- Local clips live in Files → On My iPhone → Field Camera → PendingClips. Successful Photos saves remove the local copy only after Photos reports success. Failed or interrupted files remain available for recovery. Do not delete the app while it contains unsaved clips.
- Backgrounding stops capture. Interruption/error messages are shown. Recording prevents automatic screen sleep.
- GitHub Actions workflow compiles a simulator build, builds an unsigned iPhone archive, and packages an IPA for AltStore to sign.

## Verification status — read this first

**Implemented in source, not yet proven on an iPhone.** This package was created on Windows without Xcode, an Apple SDK, or a connected iPhone test session.

Checked here: project syntax using an OpenStep parser; source references and shared scheme; permissions plist; workflow YAML and build/package paths; source review; ZIP contents. See VALIDATION.md.

**Not performed:** Swift/Apple SDK compilation, GitHub workflow execution, generation of a real IPA, AltStore signing/installation, camera launch timing, recorded 1080p30 metadata, audible sound, sync, focus/zoom behavior, meter accuracy, album creation/readback, interruption handling, long recordings, heat or battery tests. A passing cloud build checks compilation, not these hardware behaviors.

The ZIP is a **source project**, not an installable IPA. No GitHub repository has been created or published and no accounts have been signed into.

AirPods 4 ANC microphone/routing and DJI OM6 hardware controls are **later experimental work**. There is no implementation or promise of compatibility for either. Start testing with the iPhone microphone and on-screen controls.

## Free Windows → iPhone route

Feasible based on official documentation, checked October 13, 2026; this particular app's end-to-end installation is untested.

1. Build on GitHub's hosted macOS runner. Standard hosted Actions runners are free for public repositories. Private repositories have quotas and possible charges; public source is the straightforward free option. [GitHub billing documentation](https://docs.github.com/en/actions/concepts/billing-and-usage).
2. Download the resulting unsigned IPA. It cannot install by itself. AltStore Classic/AltServer re-signs it with your Apple ID for installation on your phone. Windows can handle signing/installation, but cannot compile native iOS Swift code without an Apple SDK/macOS build host. [AltStore capabilities](https://faq.altstore.io/about-us/press-kit).
3. Use **AltStore Classic**, following the [official Windows installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows), not AltStore PAL. It requires AltServer, Apple's iTunes/iCloud setup, device trust, and Developer Mode on iOS 16+.
4. With a free Apple ID, apps expire in **7 days** and must be refreshed. Apple's free limit is **3 sideloaded apps**, including AltStore. Keep AltServer available and use Refresh All before expiry. [AltStore Getting Started](https://faq.altstore.io/altstore-classic/your-altstore).

No paid Apple Developer membership is needed for this proposed personal sideloading route. It is not App Store distribution. GitHub and Apple sign-ins still need to be completed by you.

## Get your first build from Windows

1. Extract FieldCamera-SpotNews-Source.zip to a convenient folder. The project folder is **FieldCamera**. Keep the hidden `.github` folder; it contains the build workflow.
2. Install [GitHub Desktop](https://desktop.github.com/) and sign in to a free GitHub account.
3. In GitHub Desktop choose **File → Add Local Repository**, then choose the extracted **FieldCamera** folder. If it says this is not a Git repository, use its **create a repository here** link. Verify the resulting repository root contains `FieldCamera.xcodeproj`, `FieldCamera`, and `.github` together.
4. Commit any listed files using a summary such as `Initial Field Camera project`. Choose **Publish repository**. For the free public runner route, uncheck **Keep this code private**. This publishes the source files for anyone to read.
5. Open that repository on GitHub → **Actions → Build Field Camera unsigned IPA**. If it has not already started, select **Run workflow** on your default branch. Automatic push builds target `main`; the manual button also works on another default branch.
6. Wait for the run to finish. If it is red, open the failed step and save the error text; a failing build does not produce a usable IPA.
7. On a successful run, download **FieldCamera-unsigned-IPA** from **Artifacts** at the bottom of the run page. Extract the downloaded artifact ZIP to obtain `FieldCamera-unsigned.ipa`. Artifacts expire after seven days; re-run to recreate one.

## Install on iPhone with AltStore Classic

1. Follow the [official Windows guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows). It specifies Apple's direct iTunes/iCloud installers; the guide also links an alternate setup for Microsoft Store iCloud. Download AltServer from the official site.
2. Connect and unlock the iPhone by USB, trust this computer, enable Wi-Fi sync in iTunes, then use the AltServer tray icon → **Install AltStore → your iPhone**. Enter your Apple ID into AltServer's own dialog.
3. On iPhone, trust the developer under **Settings → General → VPN & Device Management** if requested. Enable **Settings → Privacy & Security → Developer Mode**, restart, and confirm when asked.
4. Transfer `FieldCamera-unsigned.ipa` to iPhone Files using a method you already use. Open **AltStore → My Apps → +** and select that IPA. Keep AltServer running on the Windows computer and reachable on the same network during signing. UI details may vary by AltStore version.
5. Open Field Camera and allow Camera and Microphone. Stop your first clip and allow **Full Photos Access** to create/use FIELD CAMERA. If the first save was refused, change Photos permissions in Settings → Field Camera, return, and tap **Save**.
6. In AltStore use **Refresh All** before the seven-day expiry, with AltServer reachable. Check the displayed expiry date; background refresh alone is not a guarantee.

## First real-device acceptance check

Use a disposable test, not a news assignment, until these pass:

1. Launch: picture appears without an extra Start button after permissions; relaunch to judge actual startup speed.
2. Record 15–30 seconds while speaking and clapping once. Move the zoom slider and tap a nearby/distant subject to check focus.
3. Stop. Open **Photos → FIELD CAMERA**, play the clip, listen for intelligible sound, and check the clap against the picture. Moving meters alone do not prove recorded audio.
4. Inspect clip information or transfer it to your editor: confirm **1920×1080**, **30 fps**, sound, duration, and correct orientation. Repeat with the phone held landscape before starting.
5. Record a second clip and check that it joins the same album. Relaunch and repeat to check album reuse.
6. Deny Full Photos Access, record a test, and confirm it remains in PendingClips. Grant Full Access and tap Save; confirm actual Photos playback before deleting recovery files.
7. Try backgrounding during a short recording; verify the stopped clip. Test a longer disposable recording and watch for heat, storage or interruptions before relying on it in the field.

## If a Mac becomes available

Open `FieldCamera.xcodeproj` in Xcode 16 or later. Select the FieldCamera scheme. For device installation through Xcode select your own team and a unique bundle identifier in Signing & Capabilities. For an unsigned compile use:

```sh
xcodebuild -project FieldCamera.xcodeproj -scheme FieldCamera \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

The cloud workflow uses the runner's default Xcode and reports its version. There are no provisioning profiles, signing certificates, Apple credentials or secrets in this project.

## Known limits

Rear wide camera only; no lens switching, manual exposure/shutter/white balance, focus lock toggle, timecode, external button integration, Bluetooth microphone selection or audio monitoring. Audio defaults to the system-selected capture microphone and needs real-device confirmation. Fixed frame duration is requested; sustained performance still needs testing. Stabilization is requested when supported and may crop the image. No background recording. Full Photos access is required for named-album saving. Low storage and interruptions may leave incomplete recovery files. A crash after Photos commits but before local cleanup may leave a duplicate on retry. There is no real-device footage included and no claim of broadcast qualification.
