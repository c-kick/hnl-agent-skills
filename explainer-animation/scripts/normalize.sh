#!/usr/bin/env bash
# Two-pass linear loudnorm: mix.wav → mix_norm.wav at -16 LUFS / -1.5 dBTP (48 kHz)
set -euo pipefail; F=node_modules/ffmpeg-static/ffmpeg
J=$($F -i mix.wav -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
g(){ echo "$J" | grep "\"$1\"" | grep -o '[-0-9.]*' | head -1; }
$F -y -loglevel error -i mix.wav -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$(g input_i):measured_TP=$(g input_tp):measured_LRA=$(g input_lra):measured_thresh=$(g input_thresh):linear=true" -ar 48000 mix_norm.wav
$F -i mix_norm.wav -af ebur128=peak=true -f null - 2>&1 | grep -A14 Summary | grep -E " I:|Peak:"
