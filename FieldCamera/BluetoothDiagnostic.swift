import CoreBluetooth
import SwiftUI

final class BluetoothDiagnostic: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [CBPeripheral] = []
    @Published var lines: [String] = []
    private var central: CBCentralManager!
    private var connected: CBPeripheral?
    private var scanTimer: Timer?
    override init() { super.init(); central = CBCentralManager(delegate: self, queue: .main) }
    func log(_ text: String) {
        lines.append("\(ISO8601DateFormatter().string(from: Date())) \(text)")
        if lines.count > 1500 { lines.removeFirst(lines.count - 1500) }
    }
    func scan() {
        guard central.state == .poweredOn else { log("Bluetooth unavailable: \(central.state.rawValue)"); return }
        devices = []
        central.scanForPeripherals(withServices: nil)
        log("Scan started (20 seconds). No device name proves OM6 identity.")
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: false) { [weak self] _ in self?.central.stopScan(); self?.log("Scan ended") }
    }
    func connect(_ peripheral: CBPeripheral) {
        stop()
        connected = peripheral
        peripheral.delegate = self
        log("Connecting \(peripheral.name ?? "Unnamed") \(peripheral.identifier)")
        central.connect(peripheral)
    }
    func stop() {
        scanTimer?.invalidate(); central.stopScan()
        if let peripheral = connected { central.cancelPeripheralConnection(peripheral) }
        connected = nil
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) { log("Bluetooth state \(central.state.rawValue)") }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if !devices.contains(where: { $0.identifier == peripheral.identifier }) {
            devices.append(peripheral)
            log("Found \(peripheral.name ?? "Unnamed") \(peripheral.identifier) RSSI \(RSSI) advertisement \(advertisementData)")
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        log("Connected; discovering accessible services"); peripheral.discoverServices(nil)
    }
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        log("Connect failed: \(error?.localizedDescription ?? "unknown")")
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        log("Disconnected: \(error?.localizedDescription ?? "requested")")
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error { log("Services: \(error.localizedDescription)"); return }
        for service in peripheral.services ?? [] { log("Service \(service.uuid)"); peripheral.discoverCharacteristics(nil, for: service) }
    }
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error { log("Characteristics: \(error.localizedDescription)"); return }
        for characteristic in service.characteristics ?? [] {
            log("Characteristic \(service.uuid)/\(characteristic.uuid) properties \(characteristic.properties.rawValue)")
            if characteristic.properties.contains(.read) { peripheral.readValue(for: characteristic) }
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        log("Subscribe \(characteristic.uuid) enabled=\(characteristic.isNotifying) error=\(error?.localizedDescription ?? "none")")
    }
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let hex = (characteristic.value ?? Data()).map { String(format: "%02X", $0) }.joined(separator: " ")
        log("RAW \(characteristic.service?.uuid.uuidString ?? "?")/\(characteristic.uuid) \(hex) error=\(error?.localizedDescription ?? "none")")
    }
}
