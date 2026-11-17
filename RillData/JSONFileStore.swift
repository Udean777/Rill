import Foundation
import os

/// Reads and writes one Codable snapshot as JSON. A missing or unreadable file
/// yields `nil`, so each store decides its own default; failures are logged.
struct JSONFileStore<Value: Codable> {
    let fileURL: URL
    var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate
    var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate
    /// Compact by default: machine data writes faster and smaller that way.
    var outputFormatting: JSONEncoder.OutputFormatting = []
    let log: Logger
    let name: String

    func read() -> Value? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = dateDecodingStrategy
            return try decoder.decode(Value.self, from: data)
        } catch {
            log.error("\(name, privacy: .public) read failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    func write(_ value: Value) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = outputFormatting
            encoder.dateEncodingStrategy = dateEncodingStrategy
            let data = try encoder.encode(value)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            log.error("\(name, privacy: .public) write failed: \(String(describing: error), privacy: .public)")
        }
    }

    func removeFile() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            log.error("\(name, privacy: .public) reset failed: \(String(describing: error), privacy: .public)")
        }
    }
}
