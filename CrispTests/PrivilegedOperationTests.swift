import XCTest

/// The root operations (S1). Parse-only: nothing here runs a command or asks for a password.
final class PrivilegedOperationTests: XCTestCase {
    private let plist = try! PropertyListSerialization.data(  // swiftlint:disable:this force_try
        fromPropertyList: ["scale-resolutions": [Data(repeating: 0, count: 8)]], format: .xml, options: 0)

    func testEveryOperationTargetsOnlyItsDisplaysOverrideFile() throws {
        let path = "/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-610/DisplayProductID-abcd"
        let operations: [PrivilegedOperation] = [
            .installDisplayOverride(vendor: 0x610, product: 0xabcd, scaledModes: [Data(repeating: 0, count: 8)]),
            .restoreDisplayOverride(vendor: 0x610, product: 0xabcd, plist: plist),
            .removeDisplayOverride(vendor: 0x610, product: 0xabcd)
        ]
        for operation in operations {
            XCTAssertEqual(operation.path, path)
            XCTAssertTrue(try operation.shellCommand().contains("'\(path)'"), "\(operation)")
        }
    }

    func testRemoveDeletesOneQuotedPathAndNothingElse() throws {
        let command = try PrivilegedOperation.removeDisplayOverride(vendor: UInt32.max, product: 0).shellCommand()
        XCTAssertEqual(command, """
            set -eu
            /bin/rm -f '/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-ffffffff/DisplayProductID-0'
            """)
        XCTAssertFalse(command.contains("-r"))
        XCTAssertFalse(command.contains("*"))
    }

    func testRestoreWritesTheOriginalBytesBack() throws {
        let command = try PrivilegedOperation.restoreDisplayOverride(vendor: 1, product: 2, plist: plist).shellCommand()
        let encoded = try XCTUnwrap(command.components(separatedBy: "/usr/bin/printf '%s' '").last?
            .components(separatedBy: "'").first)
        XCTAssertEqual(Data(base64Encoded: encoded), plist)
    }

    func testRestoreRefusesBytesThatAreNotAPropertyList() {
        for bytes in [Data(), Data("not a plist".utf8), Data(repeating: 0x41, count: 97 * 1_024)] {
            XCTAssertThrowsError(try PrivilegedOperation.restoreDisplayOverride(vendor: 1, product: 2, plist: bytes)
                .shellCommand())
        }
    }

    func testAppleScriptWrapsTheEscapedScriptOnce() throws {
        let operation = PrivilegedOperation.installDisplayOverride(
            vendor: 1, product: 2, scaledModes: [Data(repeating: 0, count: 8)])
        let source = try operation.appleScriptSource()
        XCTAssertTrue(source.hasPrefix("do shell script \""))
        XCTAssertTrue(source.hasSuffix("\" with administrator privileges"))
        // The script's own double quotes ("$stage") arrive escaped, so none ends the literal early.
        let body = source.dropFirst("do shell script \"".count).dropLast("\" with administrator privileges".count)
        XCTAssertFalse(body.replacingOccurrences(of: "\\\"", with: "").contains("\""))
    }

    /// Parse only: never execute the generated scripts.
    func testGeneratedShellSyntax() throws {
        let operations: [PrivilegedOperation] = [
            .installDisplayOverride(vendor: 1, product: 2, scaledModes: [Data(repeating: 0, count: 8)]),
            .restoreDisplayOverride(vendor: 1, product: 2, plist: plist),
            .removeDisplayOverride(vendor: 1, product: 2)
        ]
        for operation in operations {
            let process = Process()
            let input = Pipe()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-n"]
            process.standardInput = input
            try process.run()
            input.fileHandleForWriting.write(Data(try operation.shellCommand().utf8))
            try input.fileHandleForWriting.close()
            process.waitUntilExit()
            XCTAssertEqual(process.terminationStatus, 0, "\(operation)")
        }
    }
}
