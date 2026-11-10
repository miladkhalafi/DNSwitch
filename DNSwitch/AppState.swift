import Combine
import Foundation
import ServiceManagement

/// Glue: watches Wi-Fi and applies or removes DNS servers to match the rules.
@MainActor
final class AppState: ObservableObject {
    struct LogEntry: Identifiable {
        let id = UUID()
        let date = Date()
        let text: String
    }

    @Published var settings: AppSettings { didSet { saveSettings(); scheduleEvaluate() } }
    @Published private(set) var appliedServers: [String]?
    @Published private(set) var lastError: String?
    @Published private(set) var log: [LogEntry] = []
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { updateLaunchAtLogin() }
    }

    let wifi = WiFiMonitor()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let settings = "settings"
        static let original = "originalDNS"     // DNS before we changed it
        static let applied = "appliedDNS"       // what we set
    }
    private var cancellables = Set<AnyCancellable>()
    private var evaluateWork: DispatchWorkItem?

    init() {
        if let data = defaults.data(forKey: Keys.settings),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            settings = AppSettings()
        }
        appliedServers = defaults.stringArray(forKey: Keys.applied)

        wifi.onChange = { [weak self] in self?.scheduleEvaluate() }
        // Re-publish Wi-Fi changes so views observing AppState update.
        wifi.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        scheduleEvaluate()
    }

    // MARK: Core logic

    private func scheduleEvaluate() {
        evaluateWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.evaluate() }
        evaluateWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    func evaluate() {
        guard let service = wifiService else {
            lastError = "No Wi-Fi network service found."
            return
        }
        let target = (settings.enabled && wifi.isConnected) ? settings.servers(forSSID: wifi.ssid) : []

        if target.isEmpty {
            removeOurDNS(service: service,
                         reason: !settings.enabled ? "DNSwitch turned off"
                               : !wifi.isConnected ? "Wi-Fi disconnected"
                               : "no rule for \(wifi.ssid ?? "this network")")
            return
        }
        guard target != appliedServers else { return }

        do {
            // Remember what was there before the first change, to put it back later.
            if defaults.object(forKey: Keys.original) == nil {
                defaults.set(try DNSController.servers(service: service), forKey: Keys.original)
            }
            try DNSController.setServers(target, service: service)
            setApplied(target)
            lastError = nil
            addLog("Connected to \(wifi.ssid ?? "Wi-Fi"): DNS set to \(target.joined(separator: ", "))")
        } catch {
            fail("Couldn't set DNS", error)
        }
    }

    /// Undo our change, if we made one.
    func removeOurDNS(service: String? = nil, reason: String) {
        guard appliedServers != nil, let service = service ?? wifiService else { return }
        let original = defaults.stringArray(forKey: Keys.original) ?? []
        let restore = settings.disconnectAction == .restorePrevious ? original : []
        do {
            try DNSController.setServers(restore, service: service)
            setApplied(nil)
            defaults.removeObject(forKey: Keys.original)
            lastError = nil
            addLog("\(reason.prefix(1).uppercased() + reason.dropFirst()): DNS "
                   + (restore.isEmpty ? "cleared" : "restored to \(restore.joined(separator: ", "))"))
        } catch {
            fail("Couldn't remove DNS", error)
        }
    }

    /// Current DNS of the Wi-Fi service, for display.
    var currentSystemDNS: [String] {
        guard let service = wifiService else { return [] }
        return (try? DNSController.servers(service: service)) ?? []
    }

    private var wifiService: String? {
        DNSController.serviceName(forDevice: wifi.interfaceName ?? "en0")
    }

    // MARK: Helpers

    func addRuleForCurrentNetwork() {
        guard let ssid = wifi.ssid, !settings.rules.contains(where: { $0.ssid == ssid }) else { return }
        settings.rules.append(NetworkRule(ssid: ssid, servers: "1.1.1.1, 1.0.0.1"))
    }

    private func setApplied(_ servers: [String]?) {
        appliedServers = servers
        defaults.set(servers, forKey: Keys.applied)
    }

    private func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Keys.settings)
        }
    }

    private func addLog(_ text: String) {
        log.insert(LogEntry(text: text), at: 0)
        if log.count > 30 { log.removeLast() }
    }

    private func fail(_ context: String, _ error: Error) {
        lastError = "\(context): \(error.localizedDescription)"
        addLog(lastError!)
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            fail("Launch at login", error)
        }
    }
}
