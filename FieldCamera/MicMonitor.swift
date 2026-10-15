import AVFoundation
import SwiftUI

// Main-thread control only. Direct engine graph avoids an unbounded queued-audio backlog.
final class MicMonitor: ObservableObject {
    @Published var active = false
    @Published var status = "Monitor off"
    @Published var inputs: [AVAudioSessionPortDescription] = []
    @Published var selected = ""
    @Published var gain: Float = 0.1
    private var engine: AVAudioEngine?
    private var observers: [NSObjectProtocol] = []
    private let session = AVAudioSession.sharedInstance()
    init() {
        for name in [AVAudioSession.routeChangeNotification, AVAudioSession.interruptionNotification,
                     AVAudioSession.mediaServicesWereResetNotification, .AVAudioEngineConfigurationChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self = self, self.active else { return }
                self.stop("Route/interruption changed. Monitor muted; restart manually.")
            })
        }
    }
    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    func refresh() { inputs = session.availableInputs ?? [] }
    func start() {
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
            refresh()
            guard let source = inputs.first(where: { $0.uid == selected }) else {
                throw problem("Choose an available microphone first, then Start again.")
            }
            try session.setPreferredInput(source)
            let outputs = session.currentRoute.outputs
            guard !outputs.isEmpty, outputs.allSatisfy({ [.headphones, .bluetoothA2DP, .bluetoothHFP].contains($0.portType) }) else {
                throw problem("Headphones required. Select AirPods in Control Center; speaker monitoring is blocked.")
            }
            guard session.currentRoute.inputs.contains(where: { $0.uid == source.uid }) else {
                throw problem("iOS did not route the selected microphone. Monitoring blocked.")
            }
            let graph = AVAudioEngine()
            let input = graph.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw problem("Microphone format unavailable.") }
            graph.connect(input, to: graph.mainMixerNode, format: format)
            graph.mainMixerNode.outputVolume = min(gain, 0.25)
            engine = graph
            graph.prepare()
            try graph.start()
            active = true
            let estimate = (session.inputLatency + session.outputLatency + session.ioBufferDuration) * 1000
            status = "\(source.portName) → \(outputs.map { $0.portName }.joined(separator: ", ")) · reported latency ~\(Int(estimate)) ms (not measured end-to-end)"
        } catch { stop(error.localizedDescription) }
    }
    func setGain(_ value: Float) {
        gain = min(max(value, 0), 0.25)
        engine?.mainMixerNode.outputVolume = gain
    }
    func stop(_ message: String = "Monitor off") {
        engine?.mainMixerNode.outputVolume = 0
        engine?.stop()
        engine = nil
        active = false
        // Leave the shared audio session active for camera recording.
        status = message
    }
    private func problem(_ text: String) -> NSError {
        NSError(domain: "FieldCamera.Monitor", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

