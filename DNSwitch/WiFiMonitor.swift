import CoreLocation
import CoreWLAN
import Foundation
import Network

/// Watches the Wi-Fi connection and its network name (SSID).
@MainActor
final class WiFiMonitor: NSObject, ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var ssid: String?
    @Published private(set) var interfaceName: String?
    @Published private(set) var locationStatus: CLAuthorizationStatus = .notDetermined

    /// Called (debounced) whenever the connection or network changes.
    var onChange: (() -> Void)?

    private let client = CWWiFiClient.shared()
    private let pathMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let locationManager = CLLocationManager()
    private var pendingRefresh: DispatchWorkItem?

    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus

        client.delegate = self
        for event in [CWEventType.ssidDidChange, .linkDidChange, .powerDidChange] {
            try? client.startMonitoringEvent(with: event)
        }

        pathMonitor.pathUpdateHandler = { [weak self] _ in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        pathMonitor.start(queue: .main)
        refresh()
    }

    var hasLocationAccess: Bool {
        locationStatus == .authorizedAlways || locationStatus == .authorized
    }

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Wi-Fi events often come in bursts while joining a network; wait for them to settle.
    func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    func refresh() {
        let iface = client.interface()
        interfaceName = iface?.interfaceName
        let connectedViaPath = pathMonitor.currentPath.status == .satisfied
        let associated = iface?.wlanChannel() != nil
        isConnected = (iface?.powerOn() ?? false) && (associated || connectedViaPath)
        ssid = isConnected ? iface?.ssid() : nil
        onChange?()
    }
}

extension WiFiMonitor: CWEventDelegate {
    nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.scheduleRefresh() }
    }

    nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.scheduleRefresh() }
    }

    nonisolated func powerStateDidChangeForWiFiInterface(withName interfaceName: String) {
        Task { @MainActor in self.scheduleRefresh() }
    }
}

extension WiFiMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.locationStatus = status
            self.refresh()
        }
    }
}
