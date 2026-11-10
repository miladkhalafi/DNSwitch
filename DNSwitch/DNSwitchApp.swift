import AppKit
import SwiftUI

@main
struct DNSwitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environmentObject(state)
        } label: {
            Image(systemName: state.appliedServers == nil ? "wifi" : "wifi.circle.fill")
        }

        Window("DNSwitch", id: "settings") {
            SettingsView()
                .environmentObject(state)
                .frame(minWidth: 560, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
    }
}

extension AppState {
    static let shared = AppState()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        // Don't leave our DNS behind when the app quits.
        MainActor.assumeIsolated {
            AppState.shared.removeOurDNS(reason: "DNSwitch quit")
        }
    }
}

private struct MenuContent: View {
    @EnvironmentObject var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Toggle("Switch DNS automatically", isOn: $state.settings.enabled)
        Divider()
        Text(networkLine)
        Text(dnsLine)
        if let error = state.lastError {
            Text("⚠️ \(error)")
        }
        Divider()
        if let ssid = state.wifi.ssid, !state.settings.rules.contains(where: { $0.ssid == ssid }) {
            Button("Add Rule for “\(ssid)”") {
                state.addRuleForCurrentNetwork()
                openSettings()
            }
        }
        Button("Settings…", action: openSettings)
            .keyboardShortcut(",")
        Button("Quit DNSwitch") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var networkLine: String {
        guard state.wifi.isConnected else { return "Wi-Fi: not connected" }
        return "Wi-Fi: \(state.wifi.ssid ?? "connected (name hidden)")"
    }

    private var dnsLine: String {
        guard let servers = state.appliedServers else { return "DNS: not changed by DNSwitch" }
        return "DNS: \(servers.joined(separator: ", "))"
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "settings")
    }
}
