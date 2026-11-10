import AppKit
import Foundation

/// Reads and writes the DNS servers of a network service via `networksetup`.
enum DNSController {
    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private static let tool = "/usr/sbin/networksetup"

    /// Network service name ("Wi-Fi") for a device such as "en0".
    static func serviceName(forDevice device: String) -> String? {
        // Output pairs look like:
        //   (1) Wi-Fi
        //   (Hardware Port: Wi-Fi, Device: en0)
        guard let out = try? run([ "-listnetworkserviceorder" ]).output else { return nil }
        let lines = out.components(separatedBy: .newlines)
        for (i, line) in lines.enumerated() where line.contains("Device: \(device))") && i > 0 {
            let nameLine = lines[i - 1]
            if let close = nameLine.firstIndex(of: ")") {
                return nameLine[nameLine.index(after: close)...].trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    /// Manually set DNS servers ([] means none: the network's own DNS is used).
    static func servers(service: String) throws -> [String] {
        let out = try run(["-getdnsservers", service]).output
        if out.contains("aren't any DNS Servers") { return [] }
        return out.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter(DNSAddress.isValid)
    }

    /// Sets DNS servers; [] clears them. Falls back to the macOS admin
    /// password prompt if the plain call isn't allowed.
    static func setServers(_ servers: [String], service: String) throws {
        let args = ["-setdnsservers", service] + (servers.isEmpty ? ["empty"] : servers)
        let result = try run(args)
        let needsAdmin = result.status != 0 || result.output.localizedCaseInsensitiveContains("admin")
        guard needsAdmin else { return }
        try runAsAdmin(args)
    }

    // MARK: - Process helpers

    @discardableResult
    private static func run(_ args: [String]) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func runAsAdmin(_ args: [String]) throws {
        let command = ([tool] + args).map(shellQuote).joined(separator: " ")
        let source = "do shell script \"\(command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        let done = { script?.executeAndReturnError(&error) }
        if Thread.isMainThread { _ = done() } else { DispatchQueue.main.sync { _ = done() } }
        if let error {
            throw Failure(message: error[NSAppleScript.errorMessage] as? String ?? "Changing DNS was not allowed.")
        }
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
