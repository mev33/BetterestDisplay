import XCTest

/// The system-file manifest (S10): what was there first is what gets put back.
final class SystemFileRecordTests: XCTestCase {
    private let install = PrivilegedOperation.installDisplayOverride(
        vendor: 0x10ac, product: 0x4321, scaledModes: [Data(repeating: 0, count: 8)])

    func testOnlyTheFirstOriginalIsKept() {
        let first = SystemFileRecord.recording(install, original: nil, at: Date(timeIntervalSince1970: 1), in: [])
        let second = SystemFileRecord.recording(install, original: Data("later".utf8), at: Date(timeIntervalSince1970: 2),
                                                in: first)
        XCTAssertEqual(second, first)
        XCTAssertEqual(second.count, 1)
        XCTAssertNil(second[0].original)
    }

    func testEachDisplayGetsItsOwnRecord() {
        let other = PrivilegedOperation.removeDisplayOverride(vendor: 0x10ac, product: 0x9999)
        let records = SystemFileRecord.recording(
            other, original: Data("x".utf8), at: Date(),
            in: SystemFileRecord.recording(install, original: nil, at: Date(), in: []))
        XCTAssertEqual(records.map(\.product), [0x4321, 0x9999])
    }

    func testAFileThatDidNotExistIsRemovedAndOneThatDidIsRewritten() {
        let absent = SystemFileRecord(vendor: 1, product: 2, original: nil, firstChanged: Date())
        XCTAssertEqual(absent.restoreOperation, .removeDisplayOverride(vendor: 1, product: 2))
        let bytes = Data("<plist/>".utf8)
        let present = SystemFileRecord(vendor: 1, product: 2, original: bytes, firstChanged: Date())
        XCTAssertEqual(present.restoreOperation, .restoreDisplayOverride(vendor: 1, product: 2, plist: bytes))
    }

    func testRecordsSurviveARoundTripThroughJSON() throws {
        let records = [SystemFileRecord(vendor: 1, product: 2, original: Data([1, 2, 3]),
                                        firstChanged: Date(timeIntervalSince1970: 1_700_000_000))]
        let decoded = try JSONDecoder().decode([SystemFileRecord].self, from: JSONEncoder().encode(records))
        XCTAssertEqual(decoded, records)
    }
}
