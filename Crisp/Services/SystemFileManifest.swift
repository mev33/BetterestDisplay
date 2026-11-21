import Foundation
import os

/// Every system file this app has changed as root (today: the HiDPI override plists in
/// /Library/Displays), each with a copy of what was there before the first change.
/// Advanced Settings > System Files puts them all back.
///
/// If the app itself can't run, the same files can be removed by hand from Safe Mode
/// or macOS Recovery: delete /Library/Displays/Contents/Resources/Overrides/DisplayVendorID-*
/// folders that this list names (see docs/BUILDING.md).
@MainActor
final class SystemFileManifest: ObservableObject {
    static let shared = SystemFileManifest()
    private static let log = Logger(subsystem: "com.crisp.app", category: "app")

    @Published private(set) var records: [SystemFileRecord]
    private let fileURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Crisp Offline", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("system-files.json")
        records = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([SystemFileRecord].self, from: $0) } ?? []
    }

    /// Called just before a root operation runs. The original is read without
    /// privileges: the override plists are world-readable.
    func recordOriginal(before operation: PrivilegedOperation) {
        let original = FileManager.default.contents(atPath: operation.path)
        let updated = SystemFileRecord.recording(operation, original: original, at: Date(), in: records)
        guard updated != records else { return }
        records = updated
        save()
    }

    /// Puts every recorded file back as it was, behind one administrator prompt (macOS
    /// keeps the authorization for a few minutes), and re-probes the displays. Files
    /// that could not be restored stay listed. Returns their error messages.
    func restoreAll() -> [String] {
        var failures: [String] = []
        var remaining: [SystemFileRecord] = []
        for (index, record) in records.enumerated() {
            if let error = HiDPIService.shared.runPrivileged(record.restoreOperation) {
                failures.append("\(record.path): \(error)")
                remaining.append(record)
                // A cancelled password prompt means "not now": don't ask again per file.
                if error == HiDPIService.authorizationCanceled {
                    remaining += records.dropFirst(index + 1)
                    break
                }
            } else {
                HiDPIService.shared.triggerDisplayReenumeration(vendor: record.vendor, product: record.product)
            }
        }
        records = remaining
        save()
        return failures
    }

    private func save() {
        do {
            try JSONEncoder().encode(records).write(to: fileURL, options: .atomic)
        } catch {
            Self.log.error("system file manifest save failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
