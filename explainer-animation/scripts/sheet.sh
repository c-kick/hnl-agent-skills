#!/usr/bin/env bash
# 2×2 contact sheet from four shots.mjs frames.
# Usage: sheet.sh out.jpg a b c d   (times exactly as passed to shots.mjs; 12.0 and 12 both map to shot_12.jpg)
set -euo pipefail
F=node_modules/ffmpeg-static/ffmpeg; o=$1; shift
[ $# -eq 4 ] || { echo "need 4 times" >&2; exit 1; }
in=(); for t in "$@"; do f="shot_$(node -p "String(Number('$t'))").jpg"; [ -f "$f" ] || { echo "missing $f (run node shots.mjs $t)" >&2; exit 1; }; in+=(-i "$f"); done
$F -y -loglevel error "${in[@]}" -filter_complex "[0]scale=960:540[a];[1]scale=960:540[b];[2]scale=960:540[c];[3]scale=960:540[d];[a][b]hstack[t];[c][d]hstack[u];[t][u]vstack" -q:v 3 "$o"
