# Safety and privacy in BetterestDisplay

BetterestDisplay, an offline fork of Crisp, runs code with administrator rights,
Accessibility access and direct access to monitor hardware. This page lists everything it can do with those, and how to undo it.

## No network, ever

- The app and `bdctl` contain no networking code and no updater. `scripts/check-no-network.sh`
  enforces this in `make check`, in the pre-push hook and on every build:
  - The source scan fails on any networking API, web view, updater, metrics upload or URL literal.
  - The build-script scan fails on any downloader.
  - The binary scan (`nm -u`, `otool -L`) fails on networking symbols or frameworks.
- `bdctl` talks to the app over a Unix-domain socket (`bdctl.sock`) in your per-user temporary folder.
  The socket file is mode 0600, and both ends check that the peer is your own user. This
  is local communication between two processes, not network access.
- For a guarantee the kernel enforces, add a permanent **Block** rule for BetterestDisplay
  and bdctl in LuLu (Objective-See's free, open-source outbound firewall).

## What runs as root

Only the operations in `Crisp/Models/PrivilegedOperation.swift`, each behind the macOS
administrator password prompt:

| Operation | What it touches |
|---|---|
| `installDisplayOverride` | writes `/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-<hex>/DisplayProductID-<hex>` (HiDPI, smooth scaling) |
| `restoreDisplayOverride` | puts that file back exactly as it was before BetterestDisplay first changed it |
| `removeDisplayOverride` | deletes that file |

Only hex display IDs and Base64-encoded, validated plist bytes ever reach the shell.
Writes go through a root-owned staging file and an atomic rename, which replaces a
symlink instead of following it. No root helper or LaunchDaemon is installed, and
nothing runs as root in the background.

The command-line tool `bdctl` links into `~/.local/bin` as your own user, never `/usr/local/bin`,
and it never replaces a file that isn't its own link.

## Undoing system changes

Before BetterestDisplay first changes an override file, it saves the original, or notes that there
was none, in `~/Library/Application Support/BetterestDisplay/system-files.json`.
**Advanced Settings > General > System Files > Restore…** puts every file back.

If the app can't run, for example because a display stays black after a change:

1. Start in Safe Mode: on Apple Silicon, shut down, hold the power button until the
   startup options appear, choose the disk, then hold Shift and choose **Continue in Safe
   Mode**. Safe Mode doesn't open login items, so BetterestDisplay can't re-apply anything while
   you clean up. To work without a display, use SSH or Screen Sharing from another device.
2. Delete the `DisplayVendorID-*` folders that `system-files.json` names, from
   `/Library/Displays/Contents/Resources/Overrides/` (`sudo rm -r <folder>`).
   With no manifest at hand, delete the whole `Overrides` folder. BetterestDisplay is
   the only app that writes it, unless you also used another HiDPI tool or upstream Crisp.
3. Restart normally.

From macOS Recovery, the same folder is at
`/Volumes/<your disk>/Library/Displays/Contents/Resources/Overrides/`.

## Monitor hardware (DDC/CI)

- BetterestDisplay only ever addresses the DDC/CI chip (I2C address 0x37). It never writes the
  monitor's EDID memory (0x50).
- Writes are limited to an allowlist (`Crisp/Models/DDCWritePolicy.swift`): brightness,
  contrast, RGB gain, input, volume, mute and power. Factory resets, settings saves and
  manufacturer codes are refused at the one function every write passes through.
- Some monitors store DDC settings in EEPROM with a limited number of writes, so writes
  are rationed:
  - A slider drag sends at most about 10 writes a second, always the latest value.
  - Automatic brightness, which follows the built-in display, writes to a DDC monitor
    only after a change of at least 3% and at least 30 s after its last automatic write
    (`Crisp/Models/DDCWriteBudget.swift`).

## Keyboard

The brightness-key tap sees only media-key events by default. **Advanced Settings >
Keyboard > Watch Every Key Press** also taps key-down events. That's needed for brightness
keys with the lid closed, and on keyboards that send them as F14/F15. BetterestDisplay acts on those
keycodes only and never logs or stores keys.

## bdctl

- Commands that can take a display away need `--confirm`: `display disconnect`,
  `display toggle`, `display input set` and `preset apply`.
- **Advanced Settings > General > Automation > Command Line Is Read-Only** turns every
  change off over the socket, so only list and get commands work.
- Shortcuts actions run inside the app and are not affected: building the shortcut was
  the confirmation.

## Developer probes

The `scripts/*-probe.swift` files are the upstream developer's experiments. No build runs
them. `ddc-write-probe.swift` and `ddc-stress-probe.swift` send raw brightness writes to
two specific monitor models, and the stress probe sends them rapidly. Read a probe
before running it.
