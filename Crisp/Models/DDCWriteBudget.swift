import Foundation

/// How often automatic brightness may write to a DDC monitor.
///
/// A DDC brightness write is stored in the monitor's own settings memory, and some
/// monitors keep that in EEPROM rated for about 100,000 writes. Dragging a slider now
/// and then is nowhere near that, but following the built-in display's ambient-light
/// brightness all day can be. So automatic changes go to a DDC monitor in coarse,
/// spaced steps, and manual changes are only paced (BrightnessService).
enum DDCWriteBudget {
    /// The smallest automatic change worth a write, in percent.
    static let minimumAutoStep: Double = 3
    /// The least time between two automatic writes to one monitor.
    static let minimumAutoInterval: TimeInterval = 30

    static func allowsAutoWrite(from current: Double, to target: Double,
                                lastWrite: Date?, now: Date) -> Bool {
        guard abs(current - target) >= minimumAutoStep else { return false }
        guard let lastWrite else { return true }
        return now.timeIntervalSince(lastWrite) >= minimumAutoInterval
    }
}
