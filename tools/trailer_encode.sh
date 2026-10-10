#!/usr/bin/env bash
# Turns the frames tools/trailer.gd recorded into an MP4, scaled up 2x with
# nearest-neighbour so the pixel art stays sharp: 1080x2340 for the phone
# trailer, or SIZE=1920x1080 for the PC one (tools/trailer_steam.gd).
# GStreamer rather than ffmpeg because that is what this machine has.
#
#   tools/trailer_encode.sh FRAME_DIR OUT.mp4 [MUSIC.ogg]
#
# The recording carries the sound effects alone (FRAME_DIR/frame.wav, which
# Movie Maker writes beside the frames, with the music bus muted). With MUSIC
# given, that one track runs under the whole cut, faded in and out, rather than
# the game's own changes of track from scene to scene.
set -euo pipefail
dir="${1:?frame dir}"
out="${2:?output .mp4}"
music="${3:-}"
size="${SIZE:-1080x2340}"
wav="$dir/frame.wav"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ -n "$music" ]; then
  gst-launch-1.0 -q filesrc location="$music" ! decodebin ! audioconvert ! audioresample \
    ! audio/x-raw,format=S16LE,rate=48000,channels=2 ! filesink location="$tmp/music.raw"
  python3 - "$wav" "$tmp/music.raw" "$tmp/mix.wav" <<'PY'
import array, math, sys, wave
sfx_path, music_path, out_path = sys.argv[1:4]
MUSIC_GAIN = 0.5        # under the effects, not over them
FADE_IN, FADE_OUT = 0.4, 2.5

w = wave.open(sfx_path)
rate, ch, width = w.getframerate(), w.getnchannels(), w.getsampwidth()
assert rate == 48000 and ch == 2, (rate, ch)
sfx = array.array({2: "h", 4: "i"}[width], w.readframes(w.getnframes()))
sfx_full = float(1 << (8 * width - 1))
music = array.array("h")
with open(music_path, "rb") as f:
    music.frombytes(f.read())

n = len(sfx)
frames = n // 2
out = array.array("h", bytes(2 * n))
fi, fo = int(FADE_IN * rate), int(FADE_OUT * rate)
for i in range(n):
    fr = i >> 1
    g = MUSIC_GAIN
    if fr < fi:
        g *= fr / fi
    elif fr > frames - fo:
        g *= max(0.0, (frames - fr) / fo)
    m = music[i] / 32768.0 * g if i < len(music) else 0.0
    v = sfx[i] / sfx_full + m
    # Soft knee above 0.8 so a loud hit over the music never hard-clips.
    if v > 0.8:
        v = 0.8 + 0.2 * math.tanh((v - 0.8) / 0.2)
    elif v < -0.8:
        v = -0.8 + 0.2 * math.tanh((v + 0.8) / 0.2)
    out[i] = int(v * 32767)
o = wave.open(out_path, "wb")
o.setnchannels(2); o.setsampwidth(2); o.setframerate(rate)
o.writeframes(out.tobytes())
PY
  wav="$tmp/mix.wav"
fi

gst-launch-1.0 -q \
  multifilesrc location="$dir/frame%08d.png" index=0 caps="image/png,framerate=30/1" \
  ! pngdec ! videoconvert \
  ! videoscale method=nearest-neighbour ! video/x-raw,width=${size%x*},height=${size#*x} \
  ! videoconvert ! video/x-raw,format=I420 \
  ! x264enc speed-preset=slow bitrate=8000 key-int-max=60 \
  ! video/x-h264,profile=high ! queue ! mux. \
  filesrc location="$wav" ! wavparse ! audioconvert ! audioresample \
  ! avenc_aac bitrate=192000 ! queue ! mux. \
  mp4mux name=mux faststart=true ! filesink location="$out"
echo "wrote $out"
