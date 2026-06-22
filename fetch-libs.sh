#!/usr/bin/env bash
#
# Populates the (gitignored) Libs/ folder with the Ace3 libraries ZoneDetails needs, so the
# addon can be run/tested from a source checkout. macOS/Linux/WSL companion to fetch-libs.ps1.
#
# This is a LOCAL DEVELOPMENT convenience only. Released builds get their libraries from the
# externals declared in .pkgmeta via the CurseForge packager; Libs/ is gitignored and never
# committed.
#
# Requires: curl, unzip.
set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
libs="$root/Libs"
url="https://github.com/WoWUIDev/Ace3/archive/refs/heads/master.zip"

# Libraries ZoneDetails loads (see the .toc files). Each must exist in the Ace3 bundle.
needed=(
    LibStub CallbackHandler-1.0
    AceAddon-3.0 AceConsole-3.0 AceDB-3.0 AceDBOptions-3.0
    AceEvent-3.0 AceGUI-3.0 AceLocale-3.0 AceConfig-3.0 AceHook-3.0
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Ace3 libraries ..."
curl -fsSL "$url" -o "$tmp/ace3.zip"

echo "Extracting ..."
unzip -q "$tmp/ace3.zip" -d "$tmp"

# The zip extracts to a single top-level folder (e.g. Ace3-master); locate it via a known lib.
src="$(dirname "$(find "$tmp" -maxdepth 2 -type d -name 'AceAddon-3.0' | head -1)")"
[ -d "$src" ] || { echo "Could not locate the extracted Ace3 source folder." >&2; exit 1; }

mkdir -p "$libs"
for lib in "${needed[@]}"; do
    if [ -d "$src/$lib" ]; then
        rm -rf "${libs:?}/$lib"
        cp -a "$src/$lib" "$libs/$lib"
        echo "  + $lib"
    else
        echo "  ! not found in bundle: $lib" >&2
    fi
done

echo "Done. Libs/ populated for local development."
