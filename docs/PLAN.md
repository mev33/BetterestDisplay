# Plan: Replace BetterDisplay with a zero-network personal fork of Crisp

## Context

You want to stop depending on BetterDisplay, which is closed source. Its key features need the $21.99 Pro license, and v5 requires macOS 26.3 or later. Your decisions so far:

- **Target:** your own Apple Silicon Mac on macOS 26 or later.
- **Audience:** personal use only.
- **Approach:** fork **Crisp** (`didriksg/Crisp`, MIT) and add the features it lacks.
- **Hard rule: zero network access.**
- **Agreed feature categories** (every BetterDisplay feature in them is listed in §1):
  - **A. HiDPI and scaling.**
  - **B. Brightness and DDC.**
  - **C. XDR boost, EDID and display connection.**
  - **D. Color, connection modes, refresh rate and HDR.** This is your "colorspace picking, HDR/SDR bitrate, refresh mode, forced HDR, etc." I've read "bitrate" as **bit depth** (8, 10 or 12-bit, for SDR and HDR). Link bandwidth also appears in the diagnostics view (C8).

### Status (Nov 21)
- **Phase 0 is written and committed** as `601c2c4` on branch `offline-fork` in `/home/user/crisp`, on top of upstream commit `8fb8e8d`. It covers de-networking, `check-no-network.sh`, `build-app.sh`, the fork identity, and safety fixes S1–S6 and S10, plus `docs/SAFETY.md` and `docs/PLAN.md`.
- **It has not been compiled.** This container has no Swift toolchain, and your Mac isn't connected.
- **The only copy outside this container** is the `crisp-offline-fork.bundle` you downloaded.
- **Why nothing was pushed:** the branch's only remote is upstream `didriksg/Crisp`, which isn't yours, and this session's GitHub CLI token is invalid. So the next step is to push to a private repo of your own.

### Status (Nov 22)
- **`main` on `mev33/BetterestDisplay` is at `794a7d8`.** It contains Phase 0, the rename to BetterestDisplay with the `bdctl` CLI, and the bug-test fixes.
- **Tested so far, on Linux:**
  - The model files and their 80 unit tests build with Swift 6.4.3, warnings as errors, and pass.
  - Strict SwiftLint 0.65.1 is clean on the whole repo.
  - shellcheck is clean.
- **Never compiled on macOS yet.**
- **You chose to wait for your Mac** before completing phases 1–10 ("Complete planned phases and check for bugs").

## Completing phases 1–10 on your Mac

### Step 0: connect your Mac (you)
1. On the Mac:
   1. `git clone https://github.com/mev33/BetterestDisplay.git`, then `git remote add upstream https://github.com/didriksg/Crisp.git`.
   2. Install Xcode 26 or later, and run `brew install xcodegen swiftlint`.
   3. Create the **"BetterestDisplay Dev"** code-signing certificate in Keychain Access (docs/BUILDING.md).
2. Share the clone with this session: in the Claude desktop app, open **Settings → Claude Code → Remote Control** and add the `BetterestDisplay` folder.
   - **If the folder doesn't appear here:** using a folder from a cloud session isn't available to every account yet. Then open a Claude Code session on the Mac itself (the desktop app, in that folder) and continue the work there. This plan and `docs/PLAN.md` carry over.
3. Tell me it's connected. I list the shared folders and request yours, and you approve the prompt.

### Per-phase loop (me, on your Mac)
For each phase, in order:
1. **Implement**, following §5 conventions.
   - New code goes in new files.
   - Pure logic goes in `Crisp/Models/` with XCTest coverage.
   - Every hidden-API call is feature-gated.
   - The safety rules in §4 come first.
2. **Bug-check**, before anything runs on hardware:
   - `make check` must be green. It runs SwiftLint `--strict`, XCTest, the x86_64 typecheck, localization keys and `check-no-network.sh`.
   - A review pass over the phase's diff for correctness bugs.
   - The relevant §7 safety drills.
3. **Run on your displays** with `make app` or `make dev`. The rows of the §1 matrix for that phase are checked and logged in `docs/feature-checklist.md`. Anything that needs you to look at a screen or the monitor's info menu, I ask you.
4. **Commit and push** to `main` on `mev33/BetterestDisplay`, one commit per phase or sub-feature.

### Order and gates
1. **First build:** the first `make check` and `make app` on macOS. Fix whatever doesn't compile in Phase 0 and the rename, then smoke-test the existing features.
2. **Phase 1** produces `Spikes/REPORT.md`.
3. **Phases 2, 3, 4, 6, 7 and 9:** their non-gated parts go in order.
4. **Gated parts:** each follows its spike result. If a spike fails, that feature is marked "deferred" in the matrix with the reason, rather than shipped half-working.
   - Phase 5: the connection-mode encoding, depth and range pickers.
   - Phase 8: EDID override.
   - Range control (D3), built-in HDR and XDR presets (D9, D10), ProMotion (D6), HDMI-CEC (B22) and built-in HiDPI (A3).
5. **Phase 10** covers presets, `bdctl` and Shortcuts for everything that shipped.

### Blocked: this session can't reach `mev33/BetterestDisplay` yet (Nov 21) — resolved: pushed Nov 21
Attaching the repo failed. GitHub reports that this session's credential has no access to `mev33/BetterestDisplay`. Usually that means the Claude GitHub App isn't installed on the repo, or your GitHub account isn't connected. There are two ways forward:

- **A. Give this session access, then I push.**
  1. Go to **https://claude.ai/connect-github**.
  2. Connect (or reconnect) your GitHub account, and install the Claude GitHub App on `mev33/BetterestDisplay`. "Only select repositories" is fine, as long as it's included.
  3. Tell me it's done. I retry the attach once, then run the steps below.
  4. If the attach still fails, start a new session with the repo selected, and push from there using the bundle.
- **B. Push it yourself from your Mac, using the bundle you already downloaded** (needs no access from this session):
  1. `git clone https://github.com/didriksg/Crisp.git BetterestDisplay && cd BetterestDisplay`
  2. `git fetch ~/Downloads/crisp-offline-fork.bundle offline-fork:offline-fork && git checkout offline-fork`
  3. `git remote rename origin upstream`
  4. `git remote add origin https://github.com/mev33/BetterestDisplay.git`
  5. `git push -u origin offline-fork`
  6. `git push origin offline-fork:main`

**Update:** you said access is fixed ("Try now?"). An unauthenticated read (`git ls-remote`) still can't see the private repo, which is expected until it's attached. Once you approve, I retry the attach **once**.
- **If it succeeds:** I run the steps below.
- **If GitHub still refuses:** I pass on its exact reason and stop. Option B, or a new session started with the repo selected, is then the way.

### Next step (option A): push the fork to `mev33/BetterestDisplay`
Your private repo is **https://github.com/mev33/BetterestDisplay**. In `/home/user/crisp`:
1. Call `add_repo(owner: "mev33", repo: "BetterestDisplay", access: "push")` to attach it with credentials.
2. `git ls-remote https://github.com/mev33/BetterestDisplay.git` should list no branches.
   - **If it already has commits** (for example a README GitHub added), stop and ask. Don't force-push over them.
3. `git remote rename origin upstream`, so upstream Crisp stays fetchable for the monthly rebase.
4. `git remote add origin https://github.com/mev33/BetterestDisplay.git`.
5. `git push -u origin offline-fork`, retrying network errors up to 4 times with backoff (2 s, 4 s, 8 s, 16 s).
6. `git push origin offline-fork:main`, so the repo's default branch carries the fork.
7. **Check:**
   - `git ls-remote origin` lists `refs/heads/main` and `refs/heads/offline-fork` at `601c2c4`.
   - `git status -sb` shows `offline-fork...origin/offline-fork` with nothing ahead.

Nothing is pushed to `didriksg/Crisp`, and no pull request is opened there.

The app is still named Crisp inside the code, with bundle ID `local.crisp.offline`. Renaming it to BetterestDisplay is a separate change, made only if you ask for it.

§1 maps every BetterDisplay feature in these categories to one of three statuses: **Have** (Crisp already does it; checked in Phase 1), **New** or **Extend** (with a phase number), or **Excluded** (with a reason). The matrix also serves as the acceptance checklist.

---

## 1. Feature coverage matrix

Notes on the evidence:
- Crisp's status comes from reading its source: `README.md`, the full `crispctl` command list in `Crisp/Models/CrispControlModel.swift`, `Crisp/App/ShortcutsActions.swift`, and the services named below.
- "Unknown" means the relevant file wasn't read. Phase 1 confirms those, and builds them if they're missing.

### A. HiDPI and scaling
| # | BetterDisplay feature | Crisp today | Plan |
|---|---|---|---|
| A1 | HiDPI on external displays, set up automatically for 1440p and larger | **Have**: `HiDPIService.swift` override plists, at full refresh rate | Verify in Phase 1 |
| A2 | Smooth or flexible scaling on external displays | **Have**: steps of 16 pt down to 0.5× native | Verify in Phase 1 |
| A3 | Flexible scaling on the **built-in and notched** display | Unknown, probably not: the mirror path explicitly skips built-in panels | **New, Phase 3** (spike i) |
| A4 | **Custom** scaled resolution (any width × height) | No: fixed step ladder only | **New, Phase 3** |
| A5 | Scaling **beyond native** resolution through a virtual-display mirror | Partial: `MirroredModeService.swift`, but externals only, beyond-native only for 21:9+ ultrawides, and a single refresh rate | **Extend, Phase 3**: all aspect ratios, every refresh rate the panel supports, and the M4/M5 4K@2x case (force-hidpi technique) |
| A6 | Resolution slider in the menu | **Have**: `ResolutionSliderView.swift` | Nothing to do |
| A7 | Show all modes, including hidden and low-resolution duplicates | **Have**: `ResolutionService` uses private CGS mode listing | Nothing to do |
| A8 | Favorite resolutions | Unknown | **New, Phase 3** if missing |
| A9 | Rotation | **Have**: CLI and panel | Nothing to do |
| A10 | Automatic UI-scale matching across displays | No evidence | **New, Phase 3** |
| A11 | Notch handling | **Have**: notch hiding | Verify in Phase 1. Built-in scaling is A3. |
| A12 | Resolution protection | Partial: restored only after wake | **New, Phase 9** |

### B. Brightness and DDC
| # | BetterDisplay feature | Crisp today | Plan |
|---|---|---|---|
| B1 | DDC brightness | **Have** | Nothing to do |
| B2 | DDC volume, with volume keys | **Have** | Nothing to do |
| B3 | DDC mute (VCP `0x8D`) | No | **New, Phase 4** |
| B4 | DDC input switching | **Have**: CLI and Shortcuts | Nothing to do |
| B5 | Custom input names, hidden inputs, and alternate codes (LG and similar) | Partial: fixed names, raw numbers allowed | **New, Phase 4**: rename, hide, and per-display custom codes (m1ddc's LG list as reference) |
| B6 | DDC **contrast** | No: read-only | **New, Phase 4** |
| B7 | DDC hardware **RGB gain** (VCP `0x16`/`0x18`/`0x1A`) | No: read-only. Crisp's "gain" is software. | **New, Phase 4** |
| B8 | Automatic DDC setup from the monitor's capabilities string | Partial: parsed, but only used for inputs | **Extend, Phase 4**: show only the controls the monitor reports |
| B9 | DDC **power** (standby and on) | No: code defined, read-only | **New, Phase 4** |
| B10 | Brightness for built-in and Apple displays | **Have**: DisplayServices | Nothing to do |
| B11 | Software dimming | **Have**: gamma | Phase 2 fallback for the Tahoe bug |
| B12 | Combined hardware and software dimming | **Have**: blends in below 15% | Nothing to do |
| B13 | **Dim to full black** | No: 5% floor | **New, Phase 4** (with safety rule) |
| B14 | Adjustable hardware-to-software switchover point | No: fixed at 15% | **New, Phase 4** |
| B15 | Brightness keys for external displays (follow pointer, all, or a chosen subset) | **Have** | Hardened in S6 |
| B16 | Custom keyboard shortcuts | **Have**: `HotkeyService` | Nothing to do |
| B17 | OSD customization (style, position, which display) | No: fixed style and position | **New, Phase 4** |
| B18 | Sync to the built-in display's brightness and ambient light | **Have**: `AutoBrightnessService` | Rate-limited in S5 |
| B19 | Nit-normalized brightness matching | **Have**: `CombinedBrightnessMath` | Nothing to do |
| B20 | **Display groups**: sync brightness across a chosen set | No evidence | **New, Phase 4** |
| B21 | Combined brightness slider | **Have** | Nothing to do |
| B22 | HDMI-CEC (TV volume, mute, power, input) | No | **Spike (f)**, then Phase 4 if a local path exists; otherwise deferred |
| B23 | Software audio (volume for HDMI audio without DDC) | No | **Excluded**: not DDC, and it needs audio-capture permission. Can be added if you want it. |
| B24 | Network TV and receiver control (LG webOS, Samsung, Yamaha) | No | **Excluded**: breaks the zero-network rule |

### C. XDR boost, EDID and display connection
| # | BetterDisplay feature | Crisp today | Plan |
|---|---|---|---|
| C1 | XDR boost on built-in XDR panels (up to 1600 nits) | **Have**: EDR overlay | Verify in Phase 1 |
| C2 | HDR boost on external HDR displays | **Have**, but through the gamma table, so the Tahoe bug can break it | **Extend, Phase 7**: overlay method for externals as well |
| C3 | Choice of boost method | Partial: chosen automatically by display type | **New, Phase 7** |
| C4 | Pro Display XDR and Studio Display XDR | Probably: any display reporting EDR headroom qualifies | Verify in Phase 1 |
| C5 | Fix for HDR video clipping or looking overblown with boost on | No | **New, Phase 7**: pause boost while HDR content is on screen |
| C6 | EDID viewer | No | **New, Phase 8** |
| C7 | **EDID override** | No | **New, Phase 8** (spike c) |
| C8 | Connection diagnostics: link rate, lanes, DSC compression, bandwidth, current encoding and bit depth | No | **New, Phase 8**: read-only, from the IORegistry |
| C9 | Disconnect and reconnect without unplugging | **Have** | Nothing to do |
| C10 | Keep the built-in display off while docked | **Have** | Verify in Phase 1 |
| C11 | "Show only this display" in one click | Unknown | **New, Phase 4** if missing (built on C9) |
| C12 | Guard against disconnecting the last visible display | **Have** | Nothing to do |

### D. Color, connection modes, refresh rate and HDR
| # | BetterDisplay feature | Crisp today | Plan |
|---|---|---|---|
| D1 | Pixel encoding: RGB, or YCbCr with 4:4:4, 4:2:2 or 4:2:0 chroma | Partial: a raw list of whole modes, externals only | **New, Phase 5**: separate pickers |
| D2 | **Bit depth** (8, 10 or 12-bit) for SDR and HDR | Partial: only as part of a whole mode | **New, Phase 5** |
| D3 | Full or limited range (HDMI) | No | **New, Phase 5** (spike g) |
| D4 | Refresh rate picker for external displays | **Have**: mode list | Nothing to do |
| D5 | Extra or hidden refresh rates | Partial: hidden modes are listed | **Extend, Phase 6**: show every timing macOS reports |
| D6 | Built-in ProMotion refresh choice (ProMotion, 120, 60, 50, 48 Hz) | Unknown | **New, Phase 6** if missing (spike h) |
| D7 | **VRR on/off** | No: the range is detected but can't be toggled | **New, Phase 6** |
| D8 | **Forced HDR** on external displays | **Have**: `setPreferHDRModes:` through MonitorPanel | Nothing to do |
| D9 | HDR on the built-in display | No: Crisp only offers the toggle on externals | **New, Phase 7**: through the XDR presets (D10), plus a toggle if spike (d) passes |
| D10 | XDR reference preset picker (e.g. "P3-1600 nits", "HDR Video") | The README says it exists; the source wasn't read | Verify in Phase 1; **New, Phase 7** if missing |
| D11 | Automatic ICC profile switching between SDR and HDR | No | **New, Phase 7** |
| D12 | Brightness control in HDR mode (SDR white level) | No: falls back to gamma | **New, Phase 7**: overlay-based |
| D13 | ICC profile picker | **Have**: `ColorProfileService` | Nothing to do |
| D14 | Favorite color-profile slots with hotkeys and CLI | Unknown | **New, Phase 7** if missing |
| D15 | Color Profile Retouch: saturation, hue, contrast, gamma and color balance, baked into an ICC profile | No: Crisp uses gamma tables and has no saturation control | **New, Phase 7**. ICC profiles aren't affected by the Tahoe gamma bug. |
| D16 | Gamma-table image adjustments (contrast, gamma, gain, temperature, invert) | **Have**: `GammaService` | Phase 2 fallback |
| D17 | Night Shift, True Tone and Dark Mode toggles | **Have** | Nothing to do |
| D18 | Protection for color mode and profile | Partial: restored only on wake or connect | **New, Phase 9** |
| D19 | Custom 3D LUT color profiles | No | **Deferred**: experimental even in BetterDisplay, and macOS has limited support for LUT-based display profiles |
| D20 | Sharpening and geometry adjustments | No | **Excluded**: they need a screen-capture pipeline (PIP), which is out of scope |

### Every new control also gets
- Fields in presets (`Crisp/Models/DisplayPreset.swift`).
- `crispctl` verbs.
- Shortcuts actions.
- Coverage by configuration protection where it applies.

### Outside the four categories (not planned)
- Standalone virtual screens and HDR virtual screens.
- PIP, display streaming and window streaming.
- HTTP control, which breaks the zero-network rule.
- URL-scheme control and per-display commands on connect or sleep events. Both are cheap to add if you want them.
- Live Activities and Dynamic Island OSD.
- PROLED Apple-logo lighting.
- Touch-friendly menus.
- 38-language localization.

---

## 2. Competitive analysis: where each app falls short
| App | License / status | Falls short on your categories |
|---|---|---|
| **Crisp** | MIT, v1.7.1 (Oct 2026), 2.5k stars, active, 37 test files | It has the most coverage (see §1). Missing: EDID (C6–C8), separate encoding, depth and range pickers (D1–D3), VRR toggle (D7), DDC contrast, RGB gain, mute and power (B3, B6, B7, B9), dim to black (B13), display groups (B20), built-in scaling and custom scaling (A3, A4), and continuous protection. Its Sparkle updater uses the network. |
| **FreeDisplay** | MIT, Crisp's parent, 7 commits, unsigned | Explicitly excludes XDR, EDID and PIP. No volume, input switching or CLI. |
| **MonitorControl** | MIT, v4.4.0 (Sep 2026), maintenance-only | Brightness, contrast and volume only. None of A, C or D. Limited native OSD on Tahoe. |
| **Lunar** | Pro source withheld, so it **can't be built**; contributions paused | Can't be forked. No HiDPI unlock, EDID or color modes. |
| **BrightIntosh** | GPL-3.0, v6.0.12 | XDR boost only (C1). HDR video clips. |
| **m1ddc** | MIT, C CLI | DDC from the command line only. A good reference for B3–B9. |
| **displayplacer** | MIT, sparse maintenance | Modes and arrangement from the command line. Some listed modes fail, and screen IDs drift. |
| **one-key-hidpi** | No license | HiDPI plists only. Wake issues, and recovery may need macOS Recovery. |
| **force-hidpi** | M4/M5 only | 4K@2x through a virtual mirror only. Reference for A5. |
| **DeskPad, VoidDisplay, FluffyDisplay** | MIT, Apache-2.0, archived | Not display managers. |

**Bug that affects every app:**
- `CGSetDisplayTransferByTable`, which sets gamma tables, is silently ignored on some Tahoe 26.3 and 26.4 setups.
- Affected: M5 Pro, M5 Max and Neo, plus built-in XDR panels in EDR mode with auto-brightness on.
- Apple hasn't fixed it.

---

## 3. Zero-network design

### What in Crisp touches the network today
| Where | What | Action |
|---|---|---|
| `Crisp/Services/UpdateService.swift`, started in `Crisp/App/AppDelegate.swift` | Sparkle auto-update, **the only automatic network path** | Delete the file and the call. Remove the Update row in `Crisp/Views/MenuBarView.swift`, the Sparkle link and embed in `project.yml`, and the `SU*` Info.plist keys in `scripts/release.sh`. |
| `Crisp/Views/MenuBarView.swift`, `SupportRow` and `SupportLinkRow` | Donation links, opened only on click | Delete. |
| `scripts/fetch-sparkle.sh` and its callers (`make vendor`; check `dev.sh` and the `Makefile`) | Build-time `curl` from GitHub | Delete. |
| `scripts/release.sh` | Notarization and GitHub release publishing | Don't use it. |

These stay, because they're local and not network:
- `crispctl`'s Unix socket.
- `x-apple.systempreferences:` links.
- Apple Events to System Events for Dark Mode.
- Unified logging.
- "Copy Debug Info", which goes to the clipboard.

### What breaks
- **Auto-update.** You update by fetching upstream, reviewing the diff and rebuilding.
- **Donation links.**
- **Nothing on your feature list.** Every row in §1 marked Have or New is local.
- **Changes the rule forces on this plan:**
  - BetterDisplay is no longer the test reference.
  - Signing uses an offline self-signed certificate.
  - Test EDIDs are captured from your own displays.
  - Network TV control (B24) is excluded.

### One-time downloads before going offline
Xcode, `xcodegen` and `swiftlint` (through Homebrew), and the fork itself.

### Enforcement
1. **A new `scripts/check-no-network.sh`**, run by `make check` and the `.githooks/pre-push` hook. It fails on either:
   - **Source:** a grep across `Crisp/` and `Sources/` for `URLSession`, `NSURLConnection`, `import Network`, `NWConnection`, `NWPathMonitor`, `NWBrowser`, `NWListener`, `CFSocket`, `CFStream`, `CFNetwork`, `AF_INET`, `getaddrinfo`, `gethostbyname`, `NetService`, `import WebKit`, `WKWebView`, `Sparkle`, `SPU`, `MetricKit`, `http://` or `https://`, with an allowlist file.
   - **Built binaries:** `nm -u` finds `NSURLSession`, `nw_`, `getaddrinfo` or `CFSocketCreate`, or `otool -L` shows Sparkle, Network.framework or WebKit.
2. **LuLu** (Objective-See, free, open source, supports macOS 26) with a permanent **Block** rule for the app and for `crispctl`.
3. **App Sandbox stays off.** It would likely break IOKit DDC, the admin writes, the event tap and `crispctl`.

---

## 4. Safety audit

### Findings in Crisp's current code, and fixes
| # | Area | Finding | Fix |
|---|---|---|---|
| S1 | Root shell (`HiDPIService.executePrivilegedCommand`) | It interpolates the command into `do shell script … with administrator privileges` without escaping. Callers quote unevenly. Inputs are hex-only today. | Add one `PrivilegedOperation` enum that takes only typed parameters and escapes in one place. Stage files in a `mkdtemp` 0700 directory, then `install -m 0644`, and verify the SHA-256 afterwards. |
| S2 | `CrispctlInstaller.swift` | The admin fallback `ln -sfn` overwrites any file at `/usr/local/bin/crispctl`. | Install a symlink in `~/.local/bin` instead, and delete the root fallback. |
| S3 | `crispctl` socket | Good: mode 0600, a same-user `getpeereid` check, size and time limits. But **any process running as you** can disconnect displays or switch inputs. | Risky commands (EDID, connection mode, disconnect, DDC power, dim to black, protection off) need `--confirm`, and they still get the auto-revert dialog. Add a setting "CLI is read-only". Remove `crispctl skill install`. |
| S4 | DDC (`DDCService.swift`) | Good: it only ever addresses chip `0x37` and never EDID memory at `0x50`. But `writeAsync` takes **any VCP code**. | Allowlist exactly the codes in §1: `0x10`, `0x12`, `0x16`, `0x18`, `0x1A`, `0x60`, `0x62`, `0x8D` and `0xD6`. Reject everything else, especially the reset codes `0x04`, `0x05`, `0x06` and `0x08`. Add a unit test. |
| S5 | DDC write volume | Each write goes out twice, with retries and no debounce. Monitors that store settings in EEPROM may wear after many writes. | Slider writes: at most about 10 per second, then the final value on release. Auto-sync and display-group writes: only when the change is at least 3% and at least 30 s have passed. |
| S6 | Brightness-key tap (`BrightnessKeyService.swift`) | An active, session-wide tap sees **every keystroke**, though it acts on only 4 keycodes. | Tap only the media-key events by default. Make the `keyDown` tap opt-in, for keyboards that send F14/F15-style brightness keys. |
| S7 | Logging | DDC values are logged publicly in the local log. | Fine with zero network. |
| S8 | Signing | `make dev` re-signs ad hoc without hardened runtime. | Sign every build with your certificate and `--options runtime`. |
| S9 | Supply chain | You run upstream code that has root, Accessibility and hardware access. `scripts/ddc-write-probe.swift` writes DDC values. | Read `dev.sh`, the `Makefile` and `scripts/*-probe.swift` before the first build. Review the upstream diff on every rebase. |
| S10 | System files | `/Library/Displays` overrides, the `/usr/local/bin` symlink, and WindowServer plist keys later. | Keep a manifest with backups of each original. Add `crispctl restore-system`, and document Safe Mode recovery. |

### Safety rules for the new features
- **EDID:** override in macOS only. **Never write over I2C, and never to `0x50`.** Writing the monitor's own EDID chip is how displays get bricked. Enforce it with an assert and a test.
- **EDID timings:** stay inside the monitor's own advertised range limits unless an "Expert" toggle is on. Snapshot the original first.
- **All risky changes** (EDID, connection mode, VRR, range, custom HiDPI, disconnect): a 15 s "Keep these settings?" dialog that auto-reverts. Holding ⌥ at launch skips all overrides.
- **Dim to black (B13):** brightness keys and a global hotkey always restore. Leaving the app auto-restores. Holding ⌥ at launch resets it.
- **DDC power (B9):** warn that some monitors ignore DDC while in standby and need their physical button. Never power off the only visible display.
- **XDR boost:** back off when `ProcessInfo.thermalState` is `.serious` or worse. Optional "off on battery" setting and a maximum-boost cap.
- **No persistent root helper.** All re-applying runs in the app, which is a login item through `SMAppService.mainApp`.
- **Protection loop breaker:** stop after 3 failures within 30 s.
- **WindowServer crash risk:**
  - Generated ICC profiles (D15) must pass Crisp's display-profile filter, because non-display profiles crash WindowServer.
  - Run every spike with your work saved.

---

## 5. Fork setup
1. Fork into a private repo, add `upstream` as a remote, and rebase monthly. Put new code in **new files**, with small hooks into existing ones.
2. Rename the bundle ID in `project.yml` from `com.crisp.app` to something like `com.<you>.crisp`, and rename the `crisp.*` UserDefaults domain.
3. Create an **offline self-signed code-signing certificate** in Keychain Access and point `CODE_SIGN_IDENTITY` at it. A stable identity keeps Accessibility permission from resetting on each rebuild.
4. Do the de-networking (§3) and the S1–S10 fixes (§4) before adding any features.
5. Follow Crisp's conventions:
   - Services are `@MainActor` `.shared` singletons, with per-display queues for blocking work.
   - Private APIs are loaded at runtime, as `Crisp/Crisp-Bridging-Header.h` does.
   - Each user-facing string gets a key in `Crisp/Resources/Localizable.xcstrings`.
   - New model files are added to the `CrispTests` sources in `project.yml`.
   - Every new private symbol is feature-gated.
6. Build on your Mac with Xcode 26 or 27, using `xcodegen generate` and `make dev`. This cloud session runs Linux, so attach your Mac through Remote Control or build locally.

---

## 6. Phases
| Phase | Size | Work (matrix rows) |
|---|---|---|
| **0. Harden** | S | Fork setup, de-networking, and S1–S10. Exit when `make check` passes, LuLu logs zero attempts, and existing features still work. |
| **1. Audit and spikes** | S–M | Test every **Have** and **Unknown** row on your displays, and turn each Unknown into Have or New. Throwaway CLIs in `Spikes/`: **(a)** dump the CADisplay modes and `LinkDescription` fields (D1, D2, D5); **(b)** read EDID and link info from the IORegistry (C6, C8); **(c)** test EDID override two ways, runtime injection through IOAVService or an override-plist key (C7); **(d)** HDR on the built-in panel and the XDR preset APIs in MonitorPanel (D9, D10); **(e)** whether gamma changes take effect (B11, D16); **(f)** a local HDMI-CEC path (B22); **(g)** setting the range (D3); **(h)** the built-in ProMotion refresh API (D6); **(i)** override plists on the built-in panel (A3). Output: `Spikes/REPORT.md`. |
| **2. Dimming fallback** | S | `Crisp/Services/ShadeOverlayService.swift`, a black overlay built on the pattern in `EDROverlayManager.swift`. Routed from `BrightnessService.swift` when spike (e) fails (B11, D16). |
| **3. HiDPI and scaling** | M | In `HiDPIService.swift`: built-in and notched displays (A3) and custom width × height entries (A4). In `MirroredModeService.swift`: all aspect ratios and refresh rates, plus the M4/M5 4K case (A5). Favorites (A8) and UI-scale matching (A10). |
| **4. Brightness and DDC** | M | In `DDCService`, `VolumeService` and `InputSwitchService`: mute (B3), input renaming, hiding and codes (B5), contrast (B6), RGB gain (B7), showing only supported controls (B8), power (B9). In `BrightnessService` and `CombinedBrightnessMath`: dim to black (B13) and the switchover setting (B14). Then OSD options in `OSDBannerService` (B17), the new `DisplayGroupService.swift` (B20), the CEC path if found (B22), and "show only this display" (C11). |
| **5. Connection modes** | M | New `Crisp/Models/ConnectionMode.swift`. Extend `DisplayColorModeService.swift` with structured modes, `apply`, and the plist fallback through `PrivilegedOperation`. `DisplayColorModeView.swift` gets separate pickers for encoding, bit depth, range and SDR/HDR (D1–D3). |
| **6. Refresh and VRR** | S | All timings (D5), the built-in ProMotion choices (D6), and a VRR toggle built on `VariableRefreshModes.swift` and `VariableRefreshRange.swift` (D7). |
| **7. HDR, XDR and color** | M | Overlay boost for externals and a method picker (C2, C3). Pause boost on HDR content (C5). Built-in HDR and the XDR preset picker (D9, D10). Automatic SDR/HDR ICC switching in `ColorProfileService.swift` (D11). HDR-mode brightness through the overlay (D12). Favorite profile slots (D14). ICC-based **Color Retouch** with saturation, hue, contrast, gamma and balance (D15). Thermal and battery limits for boost. |
| **8. EDID and diagnostics** | L | New `Crisp/Models/EDID/` parser and writer (base block plus CTA-861). New `Crisp/Services/EDIDService.swift` to read, apply, re-apply on connect and revert. New `Crisp/Views/EDIDEditorView.swift` (C6, C7). A read-only diagnostics view for link rate, lanes, DSC, bandwidth, encoding and bit depth (C8). If spike (c) fails, override shrinks to viewing only, plus forcing RGB through Phase 5. |
| **9. Configuration protection** | M | New `Crisp/Services/ConfigurationGuardService.swift`, hooked into `DisplayManager.swift`'s reconfiguration callback. It protects resolution, refresh, VRR, rotation, connection mode, HDR, ICC and arrangement (A12, D18), and re-applies through the existing restore functions in `ResolutionService`, `DisplayColorModeService`, `PhysicalDisplayToggleService` and `BrightnessBoostService`. Includes the loop breaker. |
| **10. Polish** | S | Presets, `crispctl` and Shortcuts coverage for every new row. `crispctl restore-system`. The system-file manifest view. |

---

## 7. Verification
- **The matrix is the acceptance checklist.** A row is done only when it has been confirmed on your hardware and logged in `docs/feature-checklist.md` with the date, display and macOS version.
- **Automated (every phase):** `make check` runs SwiftLint `--strict`, XCTest with warnings treated as errors, the localization check and `check-no-network.sh`. New tests:
  - The DDC allowlist.
  - EDID code can never address `0x50`.
  - `PrivilegedOperation` escaping.
  - `ConnectionMode` parsing.
  - EDID round-trips and checksums.
  - Generated ICC profiles pass the display-profile filter.
  - Preset round-trips.
  - The protection diff function.
- **Network:** LuLu logs zero attempts during a session that uses every feature. `lsof -i -a -c <AppName>` and `nettop -p <pid>` show no internet sockets.
- **Ground truth:** `system_profiler SPDisplaysDataType -json` and `ioreg` reflect each change, and **the monitor's own OSD info screen** shows the encoding, bit depth, HDR state and refresh rate you set.
- **Safety drills:**
  - Apply a bad EDID and confirm the auto-revert.
  - Hold ⌥ at launch and confirm overrides are skipped.
  - Recover from dim-to-black with the hotkey.
  - Run `crispctl restore-system`.
  - Confirm risky CLI commands are refused without `--confirm`.
  - Try a non-allowlisted VCP code and confirm it's rejected.
- **Persistence matrix** for each feature: sleep and wake, unplug and replug, reboot, input or KVM switch, and clamshell mode.

## Sources
- BetterDisplay: https://github.com/waydabber/BetterDisplay
- Crisp: https://github.com/didriksg/Crisp
- FreeDisplay: https://github.com/huberdf/FreeDisplay
- MonitorControl: https://github.com/MonitorControl/MonitorControl
- Lunar: https://github.com/alin23/Lunar
- BrightIntosh: https://github.com/niklasr22/BrightIntosh
- m1ddc: https://github.com/waydabber/m1ddc
- displayplacer: https://github.com/jakehilborn/displayplacer
- one-key-hidpi: https://github.com/xzhih/one-key-hidpi
- force-hidpi: https://github.com/sammcj/force-hidpi
- DeskPad: https://github.com/Stengo/DeskPad
- FluffyDisplay: https://github.com/tml1024/FluffyDisplay
- Tahoe gamma bug: https://developer.apple.com/forums/thread/819331 and https://developer.apple.com/forums/thread/795074
- Force RGB on M1 gist: https://gist.github.com/GetVladimir/c89a26df1806001543bef4c8d90cc2f8
- Runtime EDID gist: https://gist.github.com/danii1/99fa5f849a4d42807418259abfbf03d5
- LuLu: https://objective-see.org/products/lulu.html
- DDC EEPROM wear: https://foliovision.com/2023/01/lunar-macos-monitor-control
- EDID chip write risks: https://wiki.debian.org/RepairEDID
- LUT display profile support thread: https://developer.apple.com/forums/thread/807131
