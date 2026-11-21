# Building the offline fork

This fork never touches the network, at build time or at runtime. You download the
tools once, then every build works with Wi-Fi off.

What the app may do with administrator rights, Accessibility and monitor hardware, and how
to undo it, is in [SAFETY.md](SAFETY.md).

## One-time setup (the only downloads)

1. Xcode 26 or later. The Command Line Tools are enough to build and run the app.
   Full Xcode is also needed for `make test`, `make loc-check` and the Shortcuts
   actions metadata.
2. `brew install xcodegen swiftlint`. Only `make test`, `make lint` and `make check` use them.
3. A stable signing identity, created offline in Keychain Access:
   **Certificate Assistant > Create a Certificate…**, name `Crisp Dev`,
   Identity Type **Self Signed Root**, Certificate Type **Code Signing**.
   With a stable identity, macOS keeps the Accessibility grant (the brightness keys)
   across rebuilds. Without one, builds are signed ad hoc and the grant resets every time.

## Build and install

```sh
make app      # full bundle: compile, icon, localizations, Info.plist, sign, install, launch
```

This runs `scripts/build-app.sh`, which installs to `/Applications/Crisp.app`. To
install somewhere else, set `CRISP_APP=/path/to/Crisp.app`. To only build into
`./build/Crisp.app`, set `CRISP_INSTALL=0`. The script refuses to replace an app with
a different bundle ID, such as an upstream Crisp install, unless `CRISP_REPLACE=1` is set.

Every build is signed with the hardened runtime. Each build also passes the binary
half of `scripts/check-no-network.sh`: no networking symbols, no networking
frameworks, no embedded frameworks and no updater feed.

## Fast loop

```sh
make dev      # recompile, swap the binary into the installed bundle, re-sign, relaunch
```

`dev.sh` swaps only into this fork's own bundle. If none is installed yet, it runs
`scripts/build-app.sh` first.

## Checks

```sh
make check    # SwiftLint --strict, unit tests, x86_64 typecheck, localization keys, no-network
make no-network
```

To run `make check` on every push, opt in once:

```sh
git config core.hooksPath .githooks
```

## Updating from upstream

There is no updater. To update, fetch upstream, read the diff, then rebuild:

```sh
git fetch upstream
git log --oneline HEAD..upstream/main
git diff HEAD...upstream/main -- scripts/ project.yml Makefile dev.sh .githooks/
git rebase upstream/main
make check && make app
```

Read every change to code that runs with admin rights, Accessibility or hardware
access before you rebuild. `make no-network` must stay green.

## crispctl

`crispctl` ships inside the bundle (`Contents/MacOS/crispctl`) and is built by both
`make app` and `make dev`. To build it on its own:

```sh
swiftc -O -swift-version 6 -target arm64-apple-macos14.0 \
  Sources/crispctl/*.swift Crisp/Models/CrispControlModel.swift Crisp/Models/BrightnessKeySteps.swift \
  -o crispctl
```

The app icon is generated from vector code: `scripts/generate-icon.swift`.
