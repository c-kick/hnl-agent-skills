#!/bin/bash
# usage: sheet.sh out.jpg a b c d  (times)
F=node_modules/ffmpeg-static/ffmpeg; o=$1; shift
$F -y -loglevel error -i shot_$1.jpg -i shot_$2.jpg -i shot_$3.jpg -i shot_$4.jpg -filter_complex "[0]scale=960:540[a];[1]scale=960:540[b];[2]scale=960:540[c];[3]scale=960:540[d];[a][b]hstack[t];[c][d]hstack[u];[t][u]vstack" -q:v 3 $o
