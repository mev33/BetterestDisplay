import XCTest

/// The socket's own checks (S3): --confirm for commands that can take a display away,
/// and the read-only setting.
final class CrispControlPolicyTests: XCTestCase {
    private func data(_ request: CrispControlRequest) throws -> Data { try JSONEncoder().encode(request) }

    func testConfirmMayStandAnywhereAndOnlySetsConfirmed() {
        let plain = CrispControlRequest(command: .disconnectDisplay, selector: "7")
        XCTAssertEqual(CrispControlCLIModel.parse(arguments: ["display", "disconnect", "7"]), .request(plain))
        for arguments in [["display", "disconnect", "7", "--confirm"], ["--confirm", "display", "disconnect", "7"]] {
            XCTAssertEqual(CrispControlCLIModel.parse(arguments: arguments), .request(plain.confirming()), "\(arguments)")
        }
    }

    func testCommandsThatCanTakeADisplayAwayNeedConfirmation() throws {
        let risky: [CrispControlRequest] = [
            .init(command: .disconnectDisplay, selector: "7"),
            .init(command: .toggleDisplay, selector: "7"),
            .init(command: .setInput, selector: "7", input: "hdmi1"),
            .init(command: .applyPreset, selector: "Desk")
        ]
        for request in risky {
            XCTAssertEqual(CrispControlModel.socketRefusal(for: try data(request), readOnly: false),
                           .failure(CrispControlModel.confirmationRefusal), "\(request.command)")
            XCTAssertNil(CrispControlModel.socketRefusal(for: try data(request.confirming()), readOnly: false))
        }
    }

    func testEverydayChangesNeedNoConfirmation() throws {
        let everyday: [CrispControlRequest] = [
            .init(command: .connectDisplay, selector: "7"),
            .init(command: .setBrightness, brightness: 40, selector: "7"),
            .init(command: .setHDR, selector: "7", enabled: true),
            .init(command: .setRotation, selector: "7", rotation: 90)
        ]
        for request in everyday {
            XCTAssertNil(CrispControlModel.socketRefusal(for: try data(request), readOnly: false), "\(request.command)")
        }
    }

    func testReadOnlyServesReadsAndRefusesEveryChangeEvenConfirmed() throws {
        let reads: [CrispControlRequest.Command] = [
            .list, .getBrightness, .getBrightnessBoost, .getHDR, .listPresets, .getImage,
            .listInputs, .listVirtualDisplays, .getRotation
        ]
        for command in reads {
            XCTAssertNil(CrispControlModel.socketRefusal(for: try data(.init(command: command, selector: "7")), readOnly: true))
        }
        let changes: [CrispControlRequest] = [
            .init(command: .setBrightness, brightness: 40, selector: "7"),
            .init(command: .connectDisplay, selector: "7"),
            .init(command: .disconnectDisplay, selector: "7", confirmed: true)
        ]
        for request in changes {
            XCTAssertEqual(CrispControlModel.socketRefusal(for: try data(request), readOnly: true),
                           .failure(CrispControlModel.readOnlyRefusal), "\(request.command)")
        }
    }

    func testAnUndecodableRequestIsLeftToHandle() {
        XCTAssertNil(CrispControlModel.socketRefusal(for: Data("{".utf8), readOnly: true))
    }

    func testTheHelpSaysWhichCommandsNeedConfirm() {
        XCTAssertTrue(CrispControlCLIModel.help.contains("--confirm"))
    }
}
