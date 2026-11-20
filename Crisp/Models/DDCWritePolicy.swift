import Foundation

/// The only DDC/CI VCP codes this app may ever write (Set VCP Feature). Enforced in
/// DDCService at the one function every write goes through, so no caller, preset,
/// Shortcut or crispctl command can send anything else to a monitor.
///
/// Not on the list on purpose: 0x04 (restore factory defaults), 0x05 (restore factory
/// brightness/contrast), 0x06 (restore geometry), 0x08 (restore color), 0x0C (save
/// settings), 0xB0 (settings save/restore) and every manufacturer-specific code
/// (0xE0-0xFF). Some of those reset or reprogram a monitor in ways Crisp can't undo.
/// EDID memory (I2C address 0x50) is never written at all: Crisp only talks to the
/// DDC/CI address (0x37).
enum DDCWritePolicy {
    static let brightness: UInt8 = 0x10
    static let contrast: UInt8 = 0x12
    static let redGain: UInt8 = 0x16
    static let greenGain: UInt8 = 0x18
    static let blueGain: UInt8 = 0x1A
    static let inputSource: UInt8 = 0x60
    static let volume: UInt8 = 0x62
    static let mute: UInt8 = 0x8D
    static let power: UInt8 = 0xD6

    static let allowedVCPCodes: Set<UInt8> = [
        brightness, contrast, redGain, greenGain, blueGain, inputSource, volume, mute, power
    ]

    static func allows(_ code: UInt8) -> Bool { allowedVCPCodes.contains(code) }
}
