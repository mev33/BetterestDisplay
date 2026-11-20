#!/bin/bash
# Fails if this offline fork could touch the network.
#
#   ./scripts/check-no-network.sh                  # scan sources + build scripts (+ ./Crisp-bin,
#                                                  #   ./crispctl-bin and the installed app if present, on macOS)
#   ./scripts/check-no-network.sh --binary PATH    # scan only PATH (a Mach-O file or a .app bundle);
#                                                  #   repeatable
#
# 1. Sources (Crisp/, Sources/, scripts/*.swift|*.py): any networking API, web view,
#    updater, metrics upload, or URL literal.
# 2. Build scripts (Makefile, dev.sh, scripts/*.sh, project.yml): any downloader
#    (curl, wget, git fetch/clone/pull, brew/pip/npm install, SwiftPM resolution).
# 3. Binaries (macOS only): undefined symbols from networking APIs (nm -u) and linked
#    networking frameworks (otool -L).
#
# The local crispctl socket is AF_UNIX and allowed; AF_INET/AF_INET6 are not.
# Known-harmless hits (a plist DTD identifier, a help message) are listed in
# scripts/no-network-allowlist.txt as "<path><TAB><literal text on the line>".
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
ALLOWLIST="$ROOT/scripts/no-network-allowlist.txt"

SOURCE_PATTERN='URLSession|NSURLConnection|NSURLRequest|NSURLDownload|import[[:space:]]+Network([^A-Za-z]|$)|NWConnection|NWPathMonitor|NWBrowser|NWListener|NWEndpoint|NWParameters|CFSocket|CFStream|CFNetwork|CFHost|AF_INET|PF_INET|sockaddr_in|inet_pton|inet_addr|getaddrinfo|gethostbyname|NetService|import[[:space:]]+WebKit|WKWebView|WebView|Sparkle|SPU[A-Z]|SUAppcast|MetricKit|MXMetricManager|https?://|ftp://|wss?://'
SCRIPT_PATTERN='curl|wget|git[[:space:]]+(clone|fetch|pull)|brew[[:space:]]+(install|upgrade|update)|pip3?[[:space:]]+install|npm[[:space:]]+(i|install)|swift[[:space:]]+package|resolvePackageDependencies|https?://'
SYMBOL_PATTERN='NSURLSession|NSURLConnection|NSURLRequest|NSURLDownload|_nw_|7Network|_getaddrinfo|_gethostbyname|_CFSocketCreate|_CFStreamCreatePairWithSocket|_CFHostCreate|NSNetService|WKWebView|SPUUpdater|SPUStandard|MXMetricManager'
LIB_PATTERN='Network\.framework|WebKit\.framework|Sparkle\.framework|CFNetwork\.framework|MetricKit\.framework'

failures=0

allowed() {  # allowed <path> <line>
    [ -f "$ALLOWLIST" ] || return 1
    local path="$1" line="$2" apath literal
    while IFS=$'\t' read -r apath literal; do
        case "$apath" in ''|'#'*) continue ;; esac
        if [ "$apath" = "$path" ] && [ -n "$literal" ] && [[ "$line" == *"$literal"* ]]; then
            return 0
        fi
    done < "$ALLOWLIST"
    return 1
}

scan() {  # scan <label> <pattern> <files...>
    local label="$1" pattern="$2"; shift 2
    local hit path rest
    [ "$#" -gt 0 ] || return 0
    while IFS= read -r hit; do
        path="${hit%%:*}"; rest="${hit#*:}"; rest="${rest#*:}"
        if allowed "$path" "$rest"; then continue; fi
        echo "  $label: $hit"
        failures=$((failures + 1))
    done < <(grep -nIE "$pattern" "$@" 2>/dev/null || true)
}

scan_binary() {  # scan_binary <Mach-O file>
    local bin="$1" sym lib
    if ! command -v nm >/dev/null || ! command -v otool >/dev/null; then
        echo "  error: nm/otool not found (binary scan needs macOS developer tools): $bin"
        failures=$((failures + 1)); return
    fi
    while IFS= read -r sym; do
        echo "  symbol: $bin imports $sym"
        failures=$((failures + 1))
    done < <(nm -u "$bin" 2>/dev/null | grep -E "$SYMBOL_PATTERN" || true)
    while IFS= read -r lib; do
        echo "  library: $bin links $lib"
        failures=$((failures + 1))
    done < <(otool -L "$bin" 2>/dev/null | tail -n +2 | grep -E "$LIB_PATTERN" || true)
}

scan_target() {  # scan_target <file or .app>
    local target="$1" f
    if [ -d "$target" ]; then
        if [ -d "$target/Contents/Frameworks" ]; then
            echo "  bundle: $target contains Contents/Frameworks (this fork embeds none)"
            failures=$((failures + 1))
        fi
        for f in "$target"/Contents/MacOS/*; do [ -f "$f" ] && scan_binary "$f"; done
        if /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$target/Contents/Info.plist" >/dev/null 2>&1; then
            echo "  plist: $target has an updater feed (SUFeedURL)"
            failures=$((failures + 1))
        fi
    elif [ -f "$target" ]; then
        scan_binary "$target"
    else
        echo "  error: no such binary or bundle: $target"
        failures=$((failures + 1))
    fi
}

binaries=()
while [ "$#" -gt 0 ]; do
    case "$1" in
        --binary) binaries+=("${2:?--binary needs a path}"); shift 2 ;;
        *) echo "usage: $0 [--binary PATH]..." >&2; exit 2 ;;
    esac
done

if [ "${#binaries[@]}" -gt 0 ]; then
    echo "==> No-network check: binaries"
    for b in "${binaries[@]}"; do scan_target "$b"; done
else
    echo "==> No-network check: sources"
    mapfile -t sources < <(find Crisp Sources scripts \( -name '*.swift' -o -name '*.h' -o -name '*.m' -o -name '*.py' \) -type f | sort)
    scan source "$SOURCE_PATTERN" "${sources[@]}"
    scan entitlements 'network\.(client|server)' Crisp/Crisp.entitlements

    echo "==> No-network check: build scripts"
    mapfile -t scripts < <( { find scripts -name '*.sh' -type f ! -name check-no-network.sh; echo Makefile; echo dev.sh; echo project.yml; } | sort)
    scan script "$SCRIPT_PATTERN" "${scripts[@]}"

    if [ "$(uname -s)" = Darwin ]; then
        for b in Crisp-bin crispctl-bin "${CRISP_APP:-/Applications/Crisp.app}"; do
            [ -e "$b" ] || continue
            echo "==> No-network check: $b"
            scan_target "$b"
        done
    fi
fi

if [ "$failures" -gt 0 ]; then
    echo "FAIL: $failures possible network path(s). Remove them, or if one is provably harmless," >&2
    echo "add '<path><TAB><literal text>' to scripts/no-network-allowlist.txt with a reason." >&2
    exit 1
fi
echo "OK: no network code found."
