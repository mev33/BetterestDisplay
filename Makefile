# Crisp (offline personal fork): convenience wrappers around the build scripts.
#
# This fork never touches the network, at build time or at runtime:
#   make app        build the full app bundle with swiftc, sign it, install to /Applications/Crisp.app
#   make dev        fast loop: recompile, swap the binary into the installed app, re-sign, relaunch
#   make compile    compile the binary only (./Crisp-bin), no swap: quick build check
#   make test       generate the Xcode project and run unit tests
#   make no-network fail if any network API or URL appears in the sources or the built binaries
#   make check      lint + tests + x86_64 typecheck + localization keys + no-network: run before pushing
#                   (auto-run on every push after: git config core.hooksPath .githooks)
#   make clean      remove build artifacts
#   make help       list targets (default)
#
# dev and app honour CRISP_APP (target bundle) and CRISP_SIGN_ID (signing identity), e.g.:
#   make app CRISP_APP=/path/to/Crisp.app CRISP_SIGN_ID="Crisp Dev"

# Single source of truth for the version: project.yml.
VERSION := $(shell grep -E '^[[:space:]]*MARKETING_VERSION:' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

# Use Xcode.app's toolchain when installed, even if xcode-select still points at
# the Command Line Tools: xcodebuild (test) and SwiftLint's SourceKit need it.
ifneq (,$(wildcard /Applications/Xcode.app))
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
# git hooks inherit SDKROOT for the Command Line Tools SDK from the git shim; with
# Xcode's swiftc that pairs a compiler and an SDK of different Swift versions.
unexport SDKROOT
endif

# swiftc invocation kept in sync with dev.sh and scripts/build-app.sh.
SWIFT_SOURCES := Crisp/App/*.swift Crisp/Models/*.swift Crisp/Services/*.swift \
                 Crisp/Views/*.swift Crisp/Utilities/*.swift
SWIFTC_FLAGS := -O -swift-version 6 -parse-as-library \
                -target arm64-apple-macos14.0 \
                -import-objc-header Crisp/Crisp-Bridging-Header.h \
                -framework AppKit -framework SwiftUI -framework IOKit -framework CoreAudio \
                -Xlinker -undefined -Xlinker dynamic_lookup

.DEFAULT_GOAL := help
.PHONY: help app dev compile test lint loc-check typecheck-x86 no-network check clean

help:
	@echo "Crisp (offline fork): make targets:"
	@echo "  make app        build + sign + install the full app bundle (scripts/build-app.sh)"
	@echo "  make dev        compile + swap into the installed app + relaunch (dev.sh)"
	@echo "  make compile    compile ./Crisp-bin only, no swap (quick build check)"
	@echo "  make test       generate the Xcode project and run unit tests"
	@echo "  make no-network source + binary scan for network APIs (scripts/check-no-network.sh)"
	@echo "  make check      lint + tests + x86_64 typecheck + localization keys + no-network"
	@echo "  make clean      remove build artifacts (Crisp-bin, build/)"

app:
	./scripts/build-app.sh

dev:
	./dev.sh

compile:
	@echo "==> Compiling Crisp $(VERSION) -> ./Crisp-bin"
	swiftc $(SWIFTC_FLAGS) $(SWIFT_SOURCES) -o Crisp-bin
	@echo "Done. ./Crisp-bin built (not swapped into the app; use 'make dev' for that)."

# Warnings are errors here (the baseline is zero, issue #47), so a change that
# introduces one fails make check. `make compile` stays permissive for
# mid-iteration builds.
test:
	xcodegen generate
	xcodebuild -quiet test -project Crisp.xcodeproj -scheme Crisp \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO \
		SWIFT_TREAT_WARNINGS_AS_ERRORS=YES

lint:
	@command -v swiftlint >/dev/null || { echo "SwiftLint not installed: brew install swiftlint"; exit 1; }
	swiftlint lint --strict --quiet

# Every key the code uses must exist in the String Catalog (missing keys silently
# fall back to English). The export writes every key it extracts into the catalog,
# so the check would pass for a key the committed catalog lacks. Put the file back
# before checking it.
loc-check:
	xcodegen generate
	mkdir -p build && cp Crisp/Resources/Localizable.xcstrings build/Localizable.xcstrings.orig
	xcodebuild -quiet -exportLocalizations -project Crisp.xcodeproj \
		-localizationPath build/loc CODE_SIGNING_ALLOWED=NO \
		SWIFT_EMIT_LOC_STRINGS=YES; status=$$?; \
		cp build/Localizable.xcstrings.orig Crisp/Resources/Localizable.xcstrings; exit $$status
	python3 scripts/check-localization-keys.py build/loc/en.xcloc \
		Crisp/Resources/Localizable.xcstrings scripts/i18n-missing-allowlist.txt

# Kept so upstream changes that only compile on arm64 are caught before a rebase
# lands, even though this fork builds arm64 only.
typecheck-x86:
	swiftc -typecheck -target x86_64-apple-macos14.0 -swift-version 6 \
		-parse-as-library -import-objc-header Crisp/Crisp-Bridging-Header.h \
		$(SWIFT_SOURCES)

# Source scan always; the binary scan also runs when a build exists
# (./Crisp-bin from make compile, or the installed app from make app / make dev).
no-network:
	./scripts/check-no-network.sh

check: lint test typecheck-x86 loc-check no-network
	@echo "check passed: lint clean, tests green, x86_64 slice typechecks, localization keys complete, no network code"

clean:
	rm -f Crisp-bin crispctl-bin
	rm -rf build
	@echo "Cleaned: Crisp-bin, crispctl-bin, build/"
