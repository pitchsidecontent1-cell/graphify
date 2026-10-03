#!/usr/bin/env bash
# Static checks: strict Luau type analysis against the Roblox API + formatting.
set -euo pipefail
cd "$(dirname "$0")"
DEFS="${ROBLOX_DEFS:-tools/globalTypes.d.luau}"
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json --definitions="$DEFS" --flag:LuauSolverV2=false --no-strict-dm-types --ignore="**/tools/**" src
stylua --check src
