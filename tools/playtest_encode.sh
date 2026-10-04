#!/usr/bin/env bash
# Turns a Movie Maker .avi of a playtest (tools/playtester.gd) into an MP4:
# scaled up 2x with nearest-neighbour so the pixel art stays sharp
# (1080x2340, phone portrait), sound kept. GStreamer, as for the trailer.
# veryfast, and an unbounded audio queue: a slower preset holds enough frames
# in its lookahead that the muxer, waiting on audio, deadlocks.
#
#   tools/playtest_encode.sh IN.avi OUT.mp4
set -euo pipefail
in="${1:?input .avi}"
out="${2:?output .mp4}"
gst-launch-1.0 -q \
  filesrc location="$in" ! avidemux name=d \
  d.video_0 ! queue ! jpegdec ! videoconvert \
    ! videoscale method=nearest-neighbour ! video/x-raw,width=1080,height=2340 \
    ! videoconvert ! video/x-raw,format=I420 \
    ! x264enc speed-preset=veryfast bitrate=4000 key-int-max=60 \
    ! video/x-h264,profile=high ! queue ! mux. \
  d.audio_0 ! queue max-size-time=0 max-size-buffers=0 max-size-bytes=0 ! audioconvert ! audioresample ! avenc_aac bitrate=160000 ! queue ! mux. \
  mp4mux name=mux faststart=true ! filesink location="$out"
echo "wrote $out"
