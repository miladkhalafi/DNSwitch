import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var state: AppState
    @State private var systemDNS: [String] = []

    var body: some View {
        Form {
            Section("Status") {
                Toggle("Switch DNS automatically", isOn: $state.settings.enabled)
                Toggle("Open at login", isOn: $state.launchAtLogin)
                LabeledContent("Wi-Fi") {
                    Text(state.wifi.isConnected ? (state.wifi.ssid ?? "Connected (name hidden)") : "Not connected")
                }
                LabeledContent("Current DNS") {
                    Text(systemDNS.isEmpty ? "Network default" : systemDNS.joined(separator: ", "))
                        .textSelection(.enabled)
                }
                if !state.wifi.hasLocationAccess {
                    HStack {
                        Label("macOS hides Wi-Fi names until DNSwitch has Location access. Without it, only the “Other networks” setting works.",
                              systemImage: "location.slash")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Allow…") {
                            if state.wifi.locationStatus == .notDetermined {
                                state.wifi.requestLocationAccess()
                            } else {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
                            }
                        }
                    }
                }
                if let error = state.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            Section {
                if state.settings.rules.isEmpty {
                    Text("No networks yet.").foregroundStyle(.secondary)
                }
                ForEach($state.settings.rules) { $rule in
                    RuleRow(rule: $rule, isCurrent: rule.ssid == state.wifi.ssid) {
                        state.settings.rules.removeAll { $0.id == rule.id }
                    }
                }
                HStack {
                    Button("Add Network") {
                        state.settings.rules.append(NetworkRule(ssid: "", servers: "1.1.1.1, 1.0.0.1"))
                    }
                    if let ssid = state.wifi.ssid, !state.settings.rules.contains(where: { $0.ssid == ssid }) {
                        Button("Add “\(ssid)”") { state.addRuleForCurrentNetwork() }
                    }
                }
            } header: {
                Text("Wi-Fi networks")
            } footer: {
                Text("When you join one of these networks, its DNS servers are set. They're removed when you disconnect.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ServersField(text: $state.settings.otherNetworksServers, placeholder: "Leave empty to not change DNS")
                Picker("When disconnecting", selection: $state.settings.disconnectAction) {
                    ForEach(DisconnectAction.allCases) { Text($0.title).tag($0) }
                }
            } header: {
                Text("Other Wi-Fi networks")
            } footer: {
                Text("DNS servers for any Wi-Fi network not listed above. Separate several servers with commas.")
                    .foregroundStyle(.secondary)
            }

            Section("Activity") {
                if state.log.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                }
                ForEach(state.log) { entry in
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.date, style: .time).foregroundStyle(.secondary).monospacedDigit()
                        Text(entry.text)
                    }
                    .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { systemDNS = state.currentSystemDNS }
        .onChange(of: state.appliedServers) { systemDNS = state.currentSystemDNS }
        .onChange(of: state.wifi.ssid) { systemDNS = state.currentSystemDNS }
    }
}

private struct RuleRow: View {
    @Binding var rule: NetworkRule
    let isCurrent: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Toggle("", isOn: $rule.enabled).labelsHidden()
            Image(systemName: isCurrent ? "wifi" : "wifi.slash")
                .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                .help(isCurrent ? "Connected now" : "Not connected")
                .frame(width: 18)
            TextField("Network name", text: $rule.ssid, prompt: Text("Network name"))
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 140)
            ServersField(text: $rule.servers, placeholder: "1.1.1.1, 1.0.0.1")
            Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                .buttonStyle(.borderless)
                .help("Remove")
        }
        .opacity(rule.enabled ? 1 : 0.5)
    }
}

private struct ServersField: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        let valid = DNSAddress.isValidList(text)
        HStack(spacing: 4) {
            TextField("", text: $text, prompt: Text(placeholder))
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            Image(systemName: valid ? "checkmark.circle" : "exclamationmark.triangle.fill")
                .foregroundStyle(valid ? Color.secondary : Color.red)
                .help(valid ? "Valid" : "Use IPv4 or IPv6 addresses separated by commas")
        }
    }
}
