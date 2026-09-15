import Foundation
import Observation

enum PowerProfile: String, Sendable {
    case battery = "Battery Power"
    case adapter = "AC Power"

}

struct PowerModeSettings: Equatable, Sendable {
    var battery: Bool?
    var adapter: Bool?

    subscript(profile: PowerProfile) -> Bool? {
        profile == .battery ? battery : adapter
    }

    init(output: String) {
        var profile: PowerProfile?
        for line in output.split(separator: "\n") {
            let text = line.trimmingCharacters(in: .whitespaces)
            if text.hasSuffix(":") {
                profile = PowerProfile(rawValue: String(text.dropLast()))
                continue
            }
            let fields = text.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2, fields[0] == "lowpowermode",
                  fields[1] == "0" || fields[1] == "1", let profile else { continue }
            if profile == .battery { battery = fields[1] == "1" }
            else { adapter = fields[1] == "1" }
        }
    }
}

@MainActor
@Observable
final class LowPowerModeService {
    private(set) var settings = PowerModeSettings(output: "")
    private var generation = 0

    func refresh() async {
        generation += 1
        let request = generation
        let result = await Task.detached {
            Self.run("/usr/bin/pmset", arguments: ["-g", "custom"])
        }.value
        guard request == generation else { return }
        settings = PowerModeSettings(output: result.code == 0 ? result.output : "")
    }

    private nonisolated static func run(_ executable: String, arguments: [String]) -> (code: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        } catch {
            return (-1, "")
        }
    }
}
