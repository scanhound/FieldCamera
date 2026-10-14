import AVFoundation
import Photos
import SwiftUI

// All capture configuration, transport and sample processing run on one serial queue.
final class CameraController: NSObject, ObservableObject, AVCaptureFileOutputRecordingDelegate,
                              AVCaptureAudioDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var ready = false
    @Published var recording = false
    @Published var busy = false
    @Published var status = "Starting camera…"
    @Published var zoom: Double = 1
    @Published var maxZoom: Double = 6
    @Published var levels: [Double] = []
    @Published var pendingCount = 0
    private let queue = DispatchQueue(label: "FieldCamera.capture")
    private let movie = AVCaptureMovieFileOutput()
    private let audio = AVCaptureAudioDataOutput()
    private var device: AVCaptureDevice?
    private var configured = false
    private var starting = false
    private var saving = false
    private var orientation: AVCaptureVideoOrientation = .portrait
    private var lastMeterTime = 0.0
    private var observers: [NSObjectProtocol] = []
    private var clipDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PendingClips", isDirectory: true)
    }
    override init() {
        super.init()
        try? FileManager.default.createDirectory(at: clipDirectory, withIntermediateDirectories: true)
        updatePendingCount()
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionWasInterrupted,
            object: session, queue: nil) { [weak self] _ in
                self?.publish { $0.ready = false; $0.status = "Camera interrupted. Keep app open to resume." }
            })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionInterruptionEnded,
            object: session, queue: nil) { [weak self] _ in self?.start() })
        observers.append(NotificationCenter.default.addObserver(forName: .AVCaptureSessionRuntimeError,
            object: session, queue: nil) { [weak self] notification in
                let error = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError
                self?.publish { $0.ready = false; $0.status = "Camera error: \(error?.localizedDescription ?? "Unknown"). Reopen app." }
            })
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    private func publish(_ body: @escaping (CameraController) -> Void) {
        DispatchQueue.main.async { [weak self] in if let self = self { body(self) } }
    }
    func start() {
        queue.async {
            guard !self.starting else { return }
            self.starting = true
            Task {
                let cameraOK = await Self.permission(.video)
                let microphoneOK = await Self.permission(.audio)
                self.queue.async {
                    defer { self.starting = false }
                    guard cameraOK && microphoneOK else {
                        self.publish { $0.status = "Allow Camera and Microphone in Settings → Field Camera." }
                        return
                    }
                    do {
                        if !self.configured { try self.configure() }
                        if !self.session.isRunning { self.session.startRunning() }
                        self.publish { $0.ready = self.session.isRunning; $0.status = "Ready" }
                    } catch { self.publish { $0.status = error.localizedDescription } }
                }
            }
        }
    }
    private static func permission(_ media: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: media) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: media)
        default: return false
        }
    }
    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        // Remove partial configuration before retrying after an error.
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        guard session.canSetSessionPreset(.hd1920x1080) else { throw failure("1080p capture is unavailable.") }
        session.sessionPreset = .hd1920x1080
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let microphone = AVCaptureDevice.default(for: .audio) else { throw failure("Camera or microphone unavailable.") }
        let videoInput = try AVCaptureDeviceInput(device: camera)
        let audioInput = try AVCaptureDeviceInput(device: microphone)
        guard session.canAddInput(videoInput), session.canAddInput(audioInput) else { throw failure("Cannot connect camera and microphone.") }
        session.addInput(videoInput)
        session.addInput(audioInput)
        guard session.canAddOutput(movie), session.canAddOutput(audio) else { throw failure("Cannot connect recording outputs.") }
        session.addOutput(movie)
        session.addOutput(audio)
        guard let format = camera.formats.first(where: {
            let size = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            return size.width == 1920 && size.height == 1080 &&
                $0.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }
        }) else { throw failure("This camera does not support 1080p30.") }
        try camera.lockForConfiguration()
        camera.activeFormat = format
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
        if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
        camera.unlockForConfiguration()
        device = camera
        audio.audioSettings = [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16,
                               AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false,
                               AVLinearPCMIsNonInterleaved: false]
        audio.setSampleBufferDelegate(self, queue: queue)
        if let connection = movie.connection(with: .video) {
            if movie.availableVideoCodecTypes.contains(.h264) {
                movie.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.h264], for: connection)
            }
            if connection.isVideoStabilizationSupported { connection.preferredVideoStabilizationMode = .standard }
        }
        configured = true
        let maximum = max(1, min(6, Double(camera.activeFormat.videoMaxZoomFactor)))
        publish { $0.maxZoom = maximum }
    }
    func suspend() {
        queue.async {
            if self.movie.isRecording { self.movie.stopRecording() }
            if self.session.isRunning { self.session.stopRunning() }
            self.publish { $0.ready = false; $0.levels = [] }
        }
    }
    func setOrientation(_ value: AVCaptureVideoOrientation) { queue.async { self.orientation = value } }
    func setZoom(_ value: Double) {
        queue.async {
            guard let camera = self.device else { return }
            do {
                try camera.lockForConfiguration()
                let value = min(max(1, value), min(6, Double(camera.activeFormat.videoMaxZoomFactor)))
                camera.videoZoomFactor = CGFloat(value)
                camera.unlockForConfiguration()
                self.publish { $0.zoom = value }
            } catch { self.publish { $0.status = "Zoom: \(error.localizedDescription)" } }
        }
    }
    func focus(at point: CGPoint) {
        queue.async {
            guard let camera = self.device else { return }
            do {
                try camera.lockForConfiguration()
                if camera.isFocusPointOfInterestSupported && camera.isFocusModeSupported(.autoFocus) {
                    camera.focusPointOfInterest = point; camera.focusMode = .autoFocus
                }
                if camera.isExposurePointOfInterestSupported && camera.isExposureModeSupported(.continuousAutoExposure) {
                    camera.exposurePointOfInterest = point; camera.exposureMode = .continuousAutoExposure
                }
                camera.unlockForConfiguration()
            } catch { self.publish { $0.status = "Focus: \(error.localizedDescription)" } }
        }
    }
    func toggleRecording() {
        // Disable immediately to prevent duplicate start/stop requests.
        busy = true
        queue.async {
            guard self.session.isRunning else { self.publish { $0.busy = false }; return }
            if self.movie.isRecording { self.movie.stopRecording(); return }
            if let connection = self.movie.connection(with: .video), connection.isVideoOrientationSupported {
                connection.videoOrientation = self.orientation
            }
            let url = self.clipDirectory.appendingPathComponent("FIELD-\(UUID().uuidString).mov")
            self.movie.startRecording(to: url, recordingDelegate: self)
        }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL,
                    from connections: [AVCaptureConnection]) {
        publish { $0.recording = true; $0.busy = false; $0.status = "Recording"; UIApplication.shared.isIdleTimerDisabled = true }
    }
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo url: URL,
                    from connections: [AVCaptureConnection], error: Error?) {
        publish { $0.recording = false; $0.busy = true; UIApplication.shared.isIdleTimerDisabled = false }
        queue.async {
            self.updatePendingCount()
            if let error = error as NSError?, !(error.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false) {
                self.publish { $0.busy = false; $0.status = "Recording error. Local file retained: \(error.localizedDescription)" }
                return
            }
            self.savePending()
        }
    }
    // Audio meters use the same microphone input as the movie; no monitoring/playback route is configured.
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        guard now - lastMeterTime >= 0.08 else { return }
        lastMeterTime = now
        guard let description = CMSampleBufferGetFormatDescription(sampleBuffer),
              let pointer = CMAudioFormatDescriptionGetStreamBasicDescription(description),
              let block = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let format = pointer.pointee
        guard format.mFormatID == kAudioFormatLinearPCM, format.mBitsPerChannel == 16,
              format.mFormatFlags & kAudioFormatFlagIsFloat == 0,
              format.mFormatFlags & kAudioFormatFlagIsNonInterleaved == 0 else { return }
        let channels = Int(format.mChannelsPerFrame)
        guard channels > 0 else { return }
        let length = CMBlockBufferGetDataLength(block)
        guard length > 0, length % 2 == 0 else { return }
        var samples = [Int16](repeating: 0, count: length / 2)
        let result = samples.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!)
        }
        guard result == kCMBlockBufferNoErr, samples.count >= channels else { return }
        var sums = [Double](repeating: 0, count: channels)
        for (index, sample) in samples.enumerated() {
            let value = Double(sample) / 32768
            sums[index % channels] += value * value
        }
        let frames = Double(samples.count / channels)
        let db = sums.map { max(-60, 20 * log10(max(0.000001, sqrt($0 / frames)))) }
        publish { $0.levels = db }
    }
    func retrySaves() { busy = true; queue.async { self.savePending() } }
    private func pendingFiles() -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: clipDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "mov" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    private func updatePendingCount() { let count = pendingFiles().count; publish { $0.pendingCount = count } }
    private func savePending() {
        guard !saving else { return }
        let files = pendingFiles()
        guard !files.isEmpty else { publish { $0.busy = false }; return }
        saving = true
        publish { $0.status = "Saving to FIELD CAMERA…" }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { permission in
            // Limited Photos cannot reliably find an existing album across launches.
            guard permission == .authorized else {
                self.queue.async { self.saving = false }
                self.publish { $0.busy = false; $0.status = "Clips kept in app. Allow Full Photos Access, then tap Save." }
                return
            }
            let options = PHFetchOptions()
            options.predicate = NSPredicate(format: "title == %@", "FIELD CAMERA")
            let existing = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options).firstObject
            PHPhotoLibrary.shared().performChanges({
                let album: PHAssetCollectionChangeRequest?
                if let existing = existing { album = PHAssetCollectionChangeRequest(for: existing) }
                else { album = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: "FIELD CAMERA") }
                for url in files {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: url, options: nil)
                    if let placeholder = request.placeholderForCreatedAsset {
                        album?.addAssets([placeholder] as NSArray)
                    }
                }
            }) { success, error in
                self.queue.async {
                    self.saving = false
                    if success { files.forEach { try? FileManager.default.removeItem(at: $0) } }
                    self.updatePendingCount()
                    self.publish {
                        $0.busy = false
                        $0.status = success ? "Saved to Photos → FIELD CAMERA" : "Save failed; clips kept in app. \(error?.localizedDescription ?? "Try again.")"
                    }
                }
            }
        }
    }
    private func failure(_ message: String) -> NSError { NSError(domain: "FieldCamera", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
