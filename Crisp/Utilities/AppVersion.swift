import Foundation

/// The running app's version (CFBundleShortVersionString).
///
/// This fork has no updater: it never contacts the network (see
/// scripts/check-no-network.sh). Update by pulling upstream, reviewing the diff
/// and rebuilding with scripts/build-app.sh.
enum AppVersion {
    static let current: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}
