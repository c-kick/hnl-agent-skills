#!/usr/bin/env bash
# Sudo-free toolchain in a scratch dir: ffmpeg-static, msedge-tts, puppeteer (+ headless shell),
# and any missing Chrome shared libs unpacked from .debs into ./libs.
# Usage: setup.sh <workdir>     then: export LD_LIBRARY_PATH=<workdir>/libs/usr/lib/x86_64-linux-gnu
set -euo pipefail
W=${1:?workdir}; mkdir -p "$W" && cd "$W"
[ -f package.json ] || npm init -y >/dev/null
npm i ffmpeg-static msedge-tts puppeteer >/dev/null 2>&1
npx --yes puppeteer browsers install chrome-headless-shell >/dev/null 2>&1 || true
H=$(ls -d ~/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-linux64 | tail -1)/chrome-headless-shell
mkdir -p libs debs
missing(){ LD_LIBRARY_PATH=$W/libs/usr/lib/x86_64-linux-gnu ldd "$H" | awk '/not found/{print $1}'; }
declare -A PKG=([libnspr4.so]=libnspr4 [libnss3.so]=libnss3 [libnssutil3.so]=libnss3 [libatk-1.0.so.0]=libatk1.0-0t64
  [libatk-bridge-2.0.so.0]=libatk-bridge2.0-0t64 [libXdamage.so.1]=libxdamage1 [libasound.so.2]=libasound2t64
  [libatspi.so.0]=libatspi2.0-0t64 [libXRes.so.1]=libxres1 [libgbm.so.1]=libgbm1 [libxkbcommon.so.0]=libxkbcommon0
  [libXcomposite.so.1]=libxcomposite1 [libXrandr.so.2]=libxrandr2 [libcups.so.2]=libcups2t64 [libpango-1.0.so.0]=libpango-1.0-0)
for round in 1 2 3; do
  M=$(missing); [ -z "$M" ] && break
  for lib in $M; do p=${PKG[$lib]:-}; [ -n "$p" ] || { echo "unknown lib $lib — find its package with apt-file/packages.ubuntu.com"; continue; }
    (cd debs && apt-get download "$p" >/dev/null 2>&1 && dpkg -x "$(ls -t ${p}_*.deb | head -1)" ../libs) || echo "could not fetch $p"; done
done
M=$(missing); [ -z "$M" ] && echo "OK: headless shell ready (export LD_LIBRARY_PATH=$W/libs/usr/lib/x86_64-linux-gnu)" || echo "STILL MISSING: $M"
echo "ffmpeg: $W/node_modules/ffmpeg-static/ffmpeg"
