import Foundation

/// Every command this app may run as root, behind the macOS administrator prompt.
///
/// Callers pick a case and pass typed values (display IDs, validated plist bytes). The
/// shell text is built here and nowhere else, and so is the escaping for the AppleScript
/// `do shell script` literal. No free-form string can reach the root shell. A new
/// privileged feature adds a case here, with a test, instead of building a command.
enum PrivilegedOperation: Equatable {
    /// Writes a display override plist with these `scale-resolutions` entries (HiDPI).
    case installDisplayOverride(vendor: UInt32, product: UInt32, scaledModes: [Data])
    /// Puts back an override plist exactly as it was before this app first changed it
    /// (SystemFileManifest). The bytes must parse as a property list.
    case restoreDisplayOverride(vendor: UInt32, product: UInt32, plist: Data)
    /// Deletes a display override plist.
    case removeDisplayOverride(vendor: UInt32, product: UInt32)

    /// The display whose override file this operation writes or removes.
    var display: (vendor: UInt32, product: UInt32) {
        switch self {
        case let .installDisplayOverride(vendor, product, _),
             let .restoreDisplayOverride(vendor, product, _),
             let .removeDisplayOverride(vendor, product):
            return (vendor, product)
        }
    }

    /// The file this operation writes or removes.
    var path: String { HiDPIOverrideCommand.destination(vendor: display.vendor, product: display.product) }

    /// The POSIX shell script that runs as root.
    func shellCommand() throws -> String {
        switch self {
        case let .installDisplayOverride(vendor, product, scaledModes):
            return try HiDPIOverrideCommand.install(vendor: vendor, product: product, scaledModes: scaledModes)
        case let .restoreDisplayOverride(vendor, product, plist):
            return try HiDPIOverrideCommand.write(vendor: vendor, product: product, plist: plist)
        case let .removeDisplayOverride(vendor, product):
            return HiDPIOverrideCommand.remove(vendor: vendor, product: product)
        }
    }

    /// The complete AppleScript that asks for the administrator password and runs the
    /// shell script. Only backslash and double quote need escaping inside an AppleScript
    /// string literal; the shell script itself quotes its own arguments.
    func appleScriptSource() throws -> String {
        let literal = HiDPIOverrideCommand.appleScriptLiteral(try shellCommand())
        return "do shell script \"\(literal)\" with administrator privileges"
    }
}
