#!/usr/bin/env bash
# Builds YoutuberEvolution.rbxl:
#   1. rojo build    -> build/base.rbxl (all scripts)
#   2. lune bake     -> runs the MapBuilder and saves the map + scripts into the final place
# Requires rojo + lune on PATH (see rokit.toml).
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
rojo build default.project.json -o build/base.rbxl
lune run tools/bake.luau build/base.rbxl YoutuberEvolution.rbxl
echo "Built YoutuberEvolution.rbxl"
