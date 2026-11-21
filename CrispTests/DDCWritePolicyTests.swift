import XCTest

/// The DDC write allowlist (S4) and the automatic-write budget (S5).
final class DDCWritePolicyTests: XCTestCase {
    func testTheControlsCrispOffersAreAllowed() {
        for code: UInt8 in [0x10, 0x12, 0x16, 0x18, 0x1A, 0x60, 0x62, 0x8D, 0xD6] {
            XCTAssertTrue(DDCWritePolicy.allows(code), String(format: "0x%02X", code))
        }
    }

    func testResetsSavesAndManufacturerCodesAreRefused() {
        let refused: [UInt8] = [0x00, 0x01, 0x02, 0x04, 0x05, 0x06, 0x08, 0x0C, 0x14, 0xB0, 0xDC, 0xDF]
            + Array(UInt8(0xE0)...UInt8(0xFF))
        for code in refused {
            XCTAssertFalse(DDCWritePolicy.allows(code), String(format: "0x%02X", code))
        }
    }

    func testTheAllowlistIsExactlyNineCodes() {
        XCTAssertEqual(DDCWritePolicy.allowedVCPCodes.count, 9)
        XCTAssertEqual((0...255).filter { DDCWritePolicy.allows(UInt8($0)) }.count, 9)
    }

    func testAutoWritesNeedABigEnoughStepAndEnoughTime() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(DDCWriteBudget.allowsAutoWrite(from: 50, to: 53, lastWrite: nil, now: now))
        XCTAssertFalse(DDCWriteBudget.allowsAutoWrite(from: 50, to: 52.9, lastWrite: nil, now: now))
        XCTAssertFalse(DDCWriteBudget.allowsAutoWrite(from: 50, to: 80, lastWrite: now.addingTimeInterval(-29), now: now))
        XCTAssertTrue(DDCWriteBudget.allowsAutoWrite(from: 50, to: 80, lastWrite: now.addingTimeInterval(-30), now: now))
        XCTAssertTrue(DDCWriteBudget.allowsAutoWrite(from: 80, to: 50, lastWrite: now.addingTimeInterval(-31), now: now))
    }
}
