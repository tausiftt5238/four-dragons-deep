#!/usr/bin/env bash
# Turns the frames tools/trailer.gd recorded into an MP4, scaled up 2x with
# nearest-neighbour so the pixel art stays sharp (1080x2340, phone portrait).
# GStreamer rather than ffmpeg because that is what this machine has.
#
#   tools/trailer_encode.sh FRAME_DIR OUT.mp4
set -euo pipefail
dir="${1:?frame dir}"
out="${2:?output .mp4}"
gst-launch-1.0 -q \
  multifilesrc location="$dir/frame%08d.png" index=0 caps="image/png,framerate=30/1" \
  ! pngdec ! videoconvert \
  ! videoscale method=nearest-neighbour ! video/x-raw,width=1080,height=2340 \
  ! videoconvert ! video/x-raw,format=I420 \
  ! x264enc speed-preset=slow bitrate=8000 key-int-max=60 \
  ! video/x-h264,profile=high \
  ! mp4mux faststart=true ! filesink location="$out"
echo "wrote $out"
