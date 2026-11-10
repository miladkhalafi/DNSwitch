import Foundation
import Network

/// "When I'm on this Wi-Fi network, use these DNS servers."
struct NetworkRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var ssid: String
    /// Comma- or space-separated list, e.g. "1.1.1.1, 1.0.0.1".
    var servers: String
    var enabled: Bool = true

    var serverList: [String] { DNSAddress.split(servers) }
}

enum DisconnectAction: String, Codable, CaseIterable, Identifiable {
    /// Put back whatever DNS servers were set before DNSwitch changed them.
    case restorePrevious
    /// Clear DNS servers so the network's own (DHCP/router) DNS is used.
    case clear

    var id: String { rawValue }
    var title: String {
        switch self {
        case .restorePrevious: "Restore the previous DNS servers"
        case .clear: "Clear DNS (use the network's own DNS)"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var enabled = true
    var rules: [NetworkRule] = []
    /// Used on Wi-Fi networks without a rule. Empty = leave DNS alone.
    var otherNetworksServers = ""
    var disconnectAction: DisconnectAction = .restorePrevious

    /// DNS servers that should be active for this Wi-Fi network, or [] for "don't touch".
    func servers(forSSID ssid: String?) -> [String] {
        if let ssid, let rule = rules.first(where: { $0.enabled && $0.ssid == ssid }) {
            return rule.serverList.filter(DNSAddress.isValid)
        }
        return DNSAddress.split(otherNetworksServers).filter(DNSAddress.isValid)
    }
}

enum DNSAddress {
    static func split(_ text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func isValid(_ address: String) -> Bool {
        if address.contains(":") { return IPv6Address(address) != nil }
        // IPv4Address accepts shorthand like "1.1.1"; require all four parts.
        return address.split(separator: ".", omittingEmptySubsequences: false).count == 4
            && IPv4Address(address) != nil
    }

    /// True if every entry is a valid IP address (an empty list is valid).
    static func isValidList(_ text: String) -> Bool {
        split(text).allSatisfy(isValid)
    }
}
