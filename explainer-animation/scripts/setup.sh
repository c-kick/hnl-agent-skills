#!/usr/bin/env bash
# Sudo-free toolchain in a scratch dir: ffmpeg-static, msedge-tts, puppeteer (+ headless shell),
# and any missing Chrome shared libs unpacked from .debs into ./libs.
# Linux x86_64 only. Missing libs are fetched with apt-get download (Debian/Ubuntu); the package map
# below uses Ubuntu 24.04 (t64) names, and older names are tried as a fallback.
# Usage: setup.sh <workdir>     then: export LD_LIBRARY_PATH=<workdir>/libs/usr/lib/x86_64-linux-gnu
set -euo pipefail
W=${1:?workdir}; mkdir -p "$W" && cd "$W"
[ -f package.json ] || npm init -y >/dev/null
[ "$(uname -sm)" = "Linux x86_64" ] || { echo "setup.sh supports Linux x86_64 only (got $(uname -sm))" >&2; exit 1; }
command -v npm >/dev/null || { echo "npm not found: install Node.js 18+ first" >&2; exit 1; }
npm i ffmpeg-static msedge-tts puppeteer >npm.log 2>&1 || { echo "npm install failed, last lines of $W/npm.log:" >&2; tail -20 npm.log >&2; exit 1; }
npx --yes puppeteer browsers install chrome-headless-shell >>npm.log 2>&1 || { echo "chrome-headless-shell download failed, see $W/npm.log" >&2; tail -20 npm.log >&2; exit 1; }
H=$(ls -d ~/.cache/puppeteer/chrome-headless-shell/*/chrome-headless-shell-linux64 2>/dev/null | tail -1)/chrome-headless-shell
[ -x "$H" ] || { echo "chrome-headless-shell not found under ~/.cache/puppeteer" >&2; exit 1; }
mkdir -p libs debs
missing(){ LD_LIBRARY_PATH=$W/libs/usr/lib/x86_64-linux-gnu ldd "$H" | awk '/not found/{print $1}'; }
declare -A PKG=([libnspr4.so]=libnspr4 [libnss3.so]=libnss3 [libnssutil3.so]=libnss3 [libatk-1.0.so.0]=libatk1.0-0t64
  [libatk-bridge-2.0.so.0]=libatk-bridge2.0-0t64 [libXdamage.so.1]=libxdamage1 [libasound.so.2]=libasound2t64
  [libatspi.so.0]=libatspi2.0-0t64 [libXRes.so.1]=libxres1 [libgbm.so.1]=libgbm1 [libxkbcommon.so.0]=libxkbcommon0
  [libXcomposite.so.1]=libxcomposite1 [libXrandr.so.2]=libxrandr2 [libcups.so.2]=libcups2t64 [libpango-1.0.so.0]=libpango-1.0-0)
for round in 1 2 3; do
  M=$(missing); [ -z "$M" ] && break
  for lib in $M; do p=${PKG[$lib]:-}; [ -n "$p" ] || { echo "unknown lib $lib — find its package with apt-file/packages.ubuntu.com"; continue; }
    command -v apt-get >/dev/null || { echo "no apt-get: install the package providing $lib yourself"; continue; }
    ok=; for q in "$p" "${p%t64}"; do
      (cd debs && apt-get download "$q" >/dev/null 2>&1 && dpkg -x "$(ls -t "${q}"_*.deb | head -1)" ../libs) && { ok=1; break; }; done
    [ -n "$ok" ] || echo "could not fetch $p"; done
done
M=$(missing); [ -z "$M" ] && echo "OK: headless shell ready (export LD_LIBRARY_PATH=$W/libs/usr/lib/x86_64-linux-gnu)" || echo "STILL MISSING: $M"
echo "ffmpeg: $W/node_modules/ffmpeg-static/ffmpeg"
