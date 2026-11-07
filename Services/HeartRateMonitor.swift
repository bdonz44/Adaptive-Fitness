import CoreBluetooth
import Foundation
import Observation
import Hybrid12Engine

/// Live heart rate over Bluetooth: WHOOP's "Heart Rate Broadcast" (or any standard
/// chest strap). Turned on in Plan > WHOOP. Remembers the device and reconnects.
@Observable
final class HeartRateMonitor: NSObject {
    enum State: Equatable {
        case off, bluetoothOff, notAllowed, searching, connecting(String), connected(String)
    }

    static let enabledKey = "hr.enabled"
    static let deviceKey = "hr.device"
    static let maxKey = "hr.max"

    private(set) var state: State = .off
    /// Latest beats per minute (nil when no fresh reading).
    private(set) var bpm: Int?
    private(set) var lastReading: Date?
    /// Recent readings, kept 4 hours, for time in zone at Finish.
    private(set) var samples: [HeartRate.Sample] = []

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }
    var isConnected: Bool { if case .connected = state { return true } else { return false } }

    /// Max heart rate for zones: set by hand in Plan > WHOOP, else the age estimate.
    var maxHR: Int {
        get {
            access(keyPath: \.maxHR)
            let set = UserDefaults.standard.integer(forKey: Self.maxKey)
            return set > 0 ? set : HeartRate.defaultMax
        }
        set {
            withMutation(keyPath: \.maxHR) { UserDefaults.standard.set(newValue, forKey: Self.maxKey) }
        }
    }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var scanTimer: Timer?

    private static let hrService = CBUUID(string: "180D")
    private static let hrMeasurement = CBUUID(string: "2A37")

    override init() {
        super.init()
        if isEnabled { start() }
    }

    /// A reading older than 5 seconds is stale (strap off or out of range).
    func freshBPM(at date: Date = Date()) -> Int? {
        guard let bpm, let t = lastReading, date.timeIntervalSince(t) < 5 else { return nil }
        return bpm
    }

    func setEnabled(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: Self.enabledKey)
        on ? start() : stop()
    }

    /// Forget the saved device and look again (for a new WHOOP or strap).
    func findAgain() {
        UserDefaults.standard.removeObject(forKey: Self.deviceKey)
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        connectOrScan()
    }

    func summary(from start: Date, to end: Date) -> HeartRate.Summary? {
        HeartRate.summary(samples, from: start, to: end, max: maxHR)
    }

    // MARK: Connection

    private func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main,
                                       options: [CBCentralManagerOptionShowPowerAlertKey: true])
        } else {
            connectOrScan()
        }
    }

    private func stop() {
        scanTimer?.invalidate()
        central?.stopScan()
        if let p = peripheral { central?.cancelPeripheralConnection(p) }
        peripheral = nil
        bpm = nil
        state = .off
    }

    private func connectOrScan() {
        guard isEnabled, let central, central.state == .poweredOn else { return }
        // The saved device, or one already connected to this phone (WHOOP's own app keeps it connected).
        if let id = UserDefaults.standard.string(forKey: Self.deviceKey).flatMap(UUID.init(uuidString:)),
           let known = central.retrievePeripherals(withIdentifiers: [id]).first {
            connect(known)
            return
        }
        let connected = central.retrieveConnectedPeripherals(withServices: [Self.hrService])
        if let p = connected.first(where: { ($0.name ?? "").localizedCaseInsensitiveContains("whoop") }) ?? connected.first {
            connect(p)
            return
        }
        state = .searching
        central.scanForPeripherals(withServices: [Self.hrService])
        // Prefer a WHOOP; if none shows up in 8 seconds, take any heart-rate device found.
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            guard let self, case .searching = self.state, let any = self.firstSeen else { return }
            self.connect(any)
        }
    }

    @ObservationIgnored private var firstSeen: CBPeripheral?

    private func connect(_ p: CBPeripheral) {
        scanTimer?.invalidate()
        central?.stopScan()
        peripheral = p
        p.delegate = self
        state = .connecting(p.name ?? "Heart rate")
        central?.connect(p)
    }

    private func record(_ value: Int) {
        let now = Date()
        bpm = value
        lastReading = now
        samples.append(HeartRate.Sample(date: now, bpm: value))
        let cutoff = now.addingTimeInterval(-4 * 3600)
        if let first = samples.first, first.date < cutoff { samples.removeAll { $0.date < cutoff } }
    }
}

extension HeartRateMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: connectOrScan()
        case .unauthorized: state = .notAllowed
        case .poweredOff: state = .bluetoothOff
        default: break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? ""
        if name.localizedCaseInsensitiveContains("whoop") {
            connect(peripheral)
        } else if firstSeen == nil {
            firstSeen = peripheral
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: Self.deviceKey)
        state = .connected(peripheral.name ?? "Heart rate")
        peripheral.discoverServices([Self.hrService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        retry()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        bpm = nil
        retry()
    }

    private func retry() {
        guard isEnabled, let p = peripheral else { return }
        state = .connecting(p.name ?? "Heart rate")
        // A pending connect waits until the device is back in range.
        central?.connect(p)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for s in peripheral.services ?? [] where s.uuid == Self.hrService {
            peripheral.discoverCharacteristics([Self.hrMeasurement], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] where c.uuid == Self.hrMeasurement {
            peripheral.setNotifyValue(true, for: c)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let value = HeartRate.bpm(fromMeasurement: [UInt8](data)) else { return }
        record(value)
    }
}
