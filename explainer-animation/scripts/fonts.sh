#!/usr/bin/env bash
# Download woff2 files from Google Fonts into ./fonts/<NameNoSpaces>.woff2
# Usage: fonts.sh "Caveat:wght@700" "Permanent+Marker" ...   [SUBSET=latin|latin-ext|cyrillic|greek|vietnamese]
# CJK/Arabic/etc. fonts are split into many unicode-range files; for those pick a family with a single
# file per subset or subset the TTF yourself — check glyph coverage for every on-screen string.
set -euo pipefail; mkdir -p fonts; SUB=${SUBSET:-latin}
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36"
for fam in "$@"; do n=$(echo "$fam" | cut -d: -f1 | tr -d +)
  css=$(curl -s -A "$UA" "https://fonts.googleapis.com/css2?family=$fam&display=block")
  url=$(echo "$css" | awk -v s="/* $SUB */" 'index($0,s){f=1} f&&/src:/{print;exit}' | grep -o 'https://[^)]*' || true)
  [ -n "$url" ] || url=$(echo "$css" | grep -o 'https://[^)]*' | head -1)
  curl -s -o "fonts/$n.woff2" "$url"; echo "$n $(stat -c%s fonts/$n.woff2) bytes"; done
