#!/usr/bin/env bash
# Short-term loudness every 3 s for a stem, e.g. music-only (VG=0 render) vs narration.
# Usage: stemcheck.sh music.wav   (remember: mono narration reads ~3 LU lower than the same voice in stereo)
set -euo pipefail; F=node_modules/ffmpeg-static/ffmpeg; f=$1
$F -i "$f" -af ebur128=metadata=1,ametadata=print:key=lavfi.r128.S:file=/dev/stdout -f null - 2>/dev/null | node -e '
let t=0,o={};require("fs").readFileSync(0,"utf8").split("\n").forEach(l=>{const m=l.match(/pts_time:([\d.]+)/);if(m)t=+m[1];const s=l.match(/r128.S=(-?[\d.]+)/);if(s){const k=Math.floor(t);if(k%3===0&&o[k]===undefined)o[k]=(+s[1]).toFixed(1)}});console.log(JSON.stringify(o))'
