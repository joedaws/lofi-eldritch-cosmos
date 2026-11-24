#!/usr/bin/env bash
# Builds the ad (lofi-eldritch-cosmos-ad.mp4) and the vertical short
# (lofi-eldritch-cosmos-short.mp4) from scratch. See README.md.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$HERE"
mkdir -p b adframes shortframes

echo "· guide screenshots"
cp guide/*.png b/

echo "· portraits"
(cd "$ROOT" && mix run --no-start "$HERE/portraits.exs" "$HERE/b")

echo "· the map, from the replay page in docs/"
python3 -m http.server 4500 --directory "$ROOT/docs" >/dev/null 2>&1 &
HTTP=$!
sleep 1
node map.js b/map.png
kill $HTTP

echo "· app screenshots, from a fresh cosmos in a throwaway data dir"
TMP="$(mktemp -d)"
export XDG_DATA_HOME="$TMP/data" XDG_CONFIG_HOME="$TMP/config" XDG_CACHE_HOME="$TMP/cache"
(cd "$ROOT" && mix cosmos.seed --yes --beings 16 >/dev/null)
(cd "$ROOT" && exec mix phx.server >"$TMP/server.log" 2>&1) &
SERVER=$!
for _ in $(seq 1 90); do curl -sf localhost:5454/ping >/dev/null && break; sleep 1; done
node app.js "$HERE/b"
kill $SERVER; pkill -f "mix phx.server" || true
unset XDG_DATA_HOME XDG_CONFIG_HOME XDG_CACHE_HOME

echo "· soundtrack"
python3 music.py music.wav

echo "· frames and video"
find adframes -name 'f*.jpg' -delete
node capture.js "$HERE" frames ad.html adframes
ffmpeg -loglevel error -y -framerate 30 -i adframes/f%05d.jpg -i music.wav \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k \
  -shortest -movflags +faststart lofi-eldritch-cosmos-ad.mp4

echo "· the vertical short"
find shortframes -name 'f*.jpg' -delete
node capture.js "$HERE" frames short.html shortframes
ffmpeg -loglevel error -y -framerate 30 -i shortframes/f%05d.jpg -i music.wav \
  -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -c:a aac -b:a 192k \
  -shortest -movflags +faststart lofi-eldritch-cosmos-short.mp4

echo "done: $HERE/lofi-eldritch-cosmos-ad.mp4 and $HERE/lofi-eldritch-cosmos-short.mp4"
