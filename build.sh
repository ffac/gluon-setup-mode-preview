#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
#
# Build the static config-mode (setup-mode) preview into ./out.
#
# Renders config mode via generate.lua against a Gluon source checkout and
# copies in the real theme CSS and the gluon-web-model JavaScript, so the
# result is a self-contained static site.
#
# Gluon checkout: $GLUON_ROOT, else the ./gluon submodule.
# Lua resolution order: $LUA, lua, lua5.1, then `nix-shell -p lua5_1`.

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"

gluon="${GLUON_ROOT:-$here/gluon}"
gluon="$(cd "$gluon" && pwd)"  # absolute, so generate.lua works from anywhere

if [ ! -d "$gluon/package" ]; then
	echo "error: no Gluon checkout at '$gluon'." >&2
	echo "  Run 'git submodule update --init --remote gluon', or set \$GLUON_ROOT." >&2
	exit 1
fi

css="$gluon/package/gluon-config-mode-theme/files/lib/gluon/config-mode/www/static/gluon.css"
js="$gluon/package/gluon-web-model/javascript/gluon-web-model.js"

# Pick a Lua interpreter.
run_lua() {
	if [ -n "${LUA:-}" ]; then
		"$LUA" "$@"
	elif command -v lua >/dev/null 2>&1; then
		lua "$@"
	elif command -v lua5.1 >/dev/null 2>&1; then
		lua5.1 "$@"
	elif command -v nix-shell >/dev/null 2>&1; then
		nix-shell -p lua5_1 --run "lua $(printf '%q ' "$@")"
	else
		echo "error: no Lua 5.1 interpreter found (set \$LUA, or install lua5.1 / nix)" >&2
		exit 1
	fi
}

# Start clean so pages no longer emitted (e.g. a removed package) don't linger.
rm -rf "$out"
mkdir -p "$out/static"

# generate.lua reads $GLUON_ROOT and writes one HTML file per config-mode page.
GLUON_ROOT="$gluon" run_lua "$here/generate.lua" "$out"

cp "$css" "$out/static/gluon.css"
cp "$js" "$out/static/gluon-web-model.js"

echo "Built preview in $out (open index.html)"
echo "Serve it with: python3 -m http.server -d $out 8000"
