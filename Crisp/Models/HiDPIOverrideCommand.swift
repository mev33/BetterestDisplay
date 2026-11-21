import Foundation

/// Builds the one-shot authorized install without a user-writable source pathname.
/// Only numeric display identifiers and Base64-encoded, validated plist bytes enter the shell.
/// Run through `PrivilegedOperation`, never directly.
enum HiDPIOverrideCommand {
    static let overridesRoot = "/Library/Displays/Contents/Resources/Overrides"

    static func directory(vendor: UInt32) -> String {
        "\(overridesRoot)/DisplayVendorID-\(String(vendor, radix: 16))"
    }

    static func destination(vendor: UInt32, product: UInt32) -> String {
        "\(directory(vendor: vendor))/DisplayProductID-\(String(product, radix: 16))"
    }

    static func install(vendor: UInt32, product: UInt32, scaledModes: [Data]) throws -> String {
        guard !scaledModes.isEmpty, scaledModes.count <= 4_096,
              scaledModes.allSatisfy({ $0.count == 8 }) else { throw InvalidModes() }
        let data = try PropertyListSerialization.data(
            fromPropertyList: ["scale-resolutions": scaledModes], format: .xml, options: 0)
        return try write(vendor: vendor, product: product, plist: data)
    }

    /// Writes these exact plist bytes as the display's override: a validated, atomic
    /// replace through a root-owned staging file. Used by `install` and to put back the
    /// original file this app replaced.
    static func write(vendor: UInt32, product: UInt32, plist data: Data) throws -> String {
        // Leave ample headroom for Base64 and the shell template below macOS's argument limit.
        guard !data.isEmpty, data.count <= 96 * 1_024,
              (try? PropertyListSerialization.propertyList(from: data, format: nil)) != nil
        else { throw InvalidModes() }
        let directory = Self.directory(vendor: vendor)
        let destination = Self.destination(vendor: vendor, product: product)
        return """
        set -eu
        /bin/mkdir -p '\(directory)'
        stage=$(/usr/bin/mktemp '\(directory)/.crisp-override.XXXXXXXX')
        trap '/bin/rm -f "$stage"' EXIT
        /usr/bin/printf '%s' '\(data.base64EncodedString())' | /usr/bin/base64 -D > "$stage"
        /usr/bin/plutil -lint -s "$stage"
        /bin/chmod 644 "$stage"
        # rename(2) replaces a symlink at the destination, it does not follow it.
        /bin/mv -f "$stage" '\(destination)'
        """
    }

    /// Removes the display's override. Only hex digits from the IDs enter the path.
    static func remove(vendor: UInt32, product: UInt32) -> String {
        """
        set -eu
        /bin/rm -f '\(destination(vendor: vendor, product: product))'
        """
    }

    /// The existing authorization helper expects an already escaped AppleScript literal.
    static func appleScriptLiteral(_ command: String) -> String {
        command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private struct InvalidModes: LocalizedError {
        var errorDescription: String? { "Invalid HiDPI scale resolutions" }
    }
}
