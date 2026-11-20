import Foundation

/// One system file this app has changed as root, with what was there before its first
/// change. Kept by SystemFileManifest so every such change can be undone, even one
/// made by a version of the app that is no longer installed.
struct SystemFileRecord: Codable, Equatable {
    let vendor: UInt32
    let product: UInt32
    /// The file's bytes before the first change, or nil when there was no file.
    let original: Data?
    let firstChanged: Date

    var path: String { HiDPIOverrideCommand.destination(vendor: vendor, product: product) }

    /// The root operation that puts the file back as it was.
    var restoreOperation: PrivilegedOperation {
        if let original {
            return .restoreDisplayOverride(vendor: vendor, product: product, plist: original)
        }
        return .removeDisplayOverride(vendor: vendor, product: product)
    }

    /// The records with this operation's file added, unless it is already there: only
    /// the state before the very first change counts as the original.
    static func recording(_ operation: PrivilegedOperation, original: Data?, at date: Date,
                          in records: [SystemFileRecord]) -> [SystemFileRecord] {
        let display = operation.display
        guard !records.contains(where: { $0.vendor == display.vendor && $0.product == display.product }) else {
            return records
        }
        return records + [SystemFileRecord(vendor: display.vendor, product: display.product,
                                           original: original, firstChanged: date)]
    }
}
