import SwiftUI
import AVKit

struct DiagnosticView: View {
    @ObservedObject var monitor: MicMonitor
    @ObservedObject var bluetooth: BluetoothDiagnostic
    let startMonitor: () -> Void
    var body: some View {
        NavigationView {
            Form {
                Section("Continuous live audio prototype") {
                    Text("Connect DJI mic and AirPods first. Select AirPods in Control Center. Bluetooth may have noticeable delay; start quietly.")
                    Picker("Microphone", selection: $monitor.selected) {
                        Text("Choose source").tag("")
                        ForEach(monitor.inputs, id: \.uid) { Text($0.portName).tag($0.uid) }
                    }.disabled(monitor.active)
                    Button("Refresh sources") { monitor.refresh() }.disabled(monitor.active)
                    HStack {
                        Button("Start monitor", action: startMonitor).disabled(monitor.active)
                        Button("Mute / Stop") { monitor.stop() }
                    }
                    Slider(value: Binding(get: { Double(monitor.gain) }, set: { monitor.setGain(Float($0)) }), in: 0...0.25)
                    Text(monitor.status).font(.caption)
                    Text("Monitoring stays on when this panel closes and across recording start/stop. Source changes briefly pause idle capture. Route changes mute monitoring; restart manually.").font(.caption)
                }
                Section("OM6 Bluetooth diagnostic") {
                    Text("Raw accessible BLE only. Record/wheel meanings are unknown. A system camera button may produce no accessible BLE event.")
                    HStack {
                        Button("Scan") { bluetooth.scan() }
                        Button("Disconnect") { bluetooth.stop() }
                    }
                    ForEach(bluetooth.devices, id: \.identifier) { peripheral in
                        Button("Connect: \(peripheral.name ?? "Unnamed") · \(peripheral.identifier.uuidString.prefix(8))") { bluetooth.connect(peripheral) }
                    }
                    Button("Mark: about to press record") { bluetooth.log("USER MARK: record test") }
                    Button("Mark: about to turn wheel") { bluetooth.log("USER MARK: wheel test") }
                    ShareLink(item: bluetooth.lines.joined(separator: "\n")) { Text("Share diagnostic log") }
                    Text(bluetooth.lines.suffix(50).joined(separator: "\n")).font(.caption2.monospaced()).textSelection(.enabled)
                }
            }.navigationTitle("Field Camera tests")
        }
    }
}

