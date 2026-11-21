import Foundation
import os

/// Puts the bundled bdctl (Contents/MacOS/bdctl) on the PATH with a symlink in
/// ~/.local/bin. No administrator prompt: the folder belongs to you. Add it to your PATH
/// once if your shell doesn't already have it: export PATH="$HOME/.local/bin:$PATH".
///
/// The link is only ever created or removed when it is a symlink: a regular file or a
/// folder at that path is not ours and is left alone.
@MainActor
enum CrispctlInstaller {
    private static let log = Logger(subsystem: "com.crisp.app", category: "app")
    static let linkDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local/bin").path
    static let linkPath = linkDirectory + "/bdctl"
    static let bundledPath = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/bdctl").path

    /// False on a dev build without bdctl and while the app runs translocated from a
    /// DMG or Downloads, where the bundle path is a temporary mount and a link to it
    /// would dangle on the next launch.
    static var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: bundledPath)
            && !bundledPath.contains("/AppTranslocation/")
    }

    /// The link must point at this bundle: a moved app offers the install again.
    static var isInstalled: Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: linkPath)) == bundledPath
    }

    static func install() {
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: linkDirectory, withIntermediateDirectories: true)
            if isSymlink(linkPath) {
                try fm.removeItem(atPath: linkPath)
            } else if fm.fileExists(atPath: linkPath) {
                log.error("bdctl install skipped: \(linkPath, privacy: .public) exists and is not a link")
                return
            }
            try fm.createSymbolicLink(atPath: linkPath, withDestinationPath: bundledPath)
        } catch {
            log.error("bdctl install failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func uninstall() {
        guard isSymlink(linkPath) else { return }
        do {
            try FileManager.default.removeItem(atPath: linkPath)
        } catch {
            log.error("bdctl uninstall failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// lstat, so a link is seen as a link even when what it points at is gone.
    private static func isSymlink(_ path: String) -> Bool {
        var info = stat()
        return lstat(path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFLNK
    }
}
