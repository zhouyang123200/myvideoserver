#!/usr/bin/env bash
# transcode_hls.sh – Convert any video file to HLS using FFmpeg
#
# Usage:
#   ./scripts/transcode_hls.sh <input_file> <output_dir>
#
# Example:
#   ./scripts/transcode_hls.sh sample.mp4 /data/hls/demo
#
# The output directory will be created if it does not exist.
# After transcoding, point your Nginx alias at the parent directory (/data/hls/)
# and your m3u8 URL will be /hls/demo/index.m3u8.

set -euo pipefail

INPUT="${1:-}"
OUTPUT_DIR="${2:-}"

if [[ -z "$INPUT" || -z "$OUTPUT_DIR" ]]; then
    echo "Usage: $0 <input_file> <output_dir>" >&2
    exit 1
fi

if ! command -v ffmpeg &>/dev/null; then
    echo "Error: ffmpeg is not installed or not in PATH" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Transcoding: $INPUT  →  $OUTPUT_DIR"

ffmpeg -i "$INPUT" \
    -c:v libx264 \
    -profile:v main \
    -pix_fmt yuv420p \
    -crf 23 \
    -preset medium \
    -c:a aac \
    -b:a 128k \
    -ac 2 \
    -f hls \
    -hls_time 6 \
    -hls_list_size 0 \
    -hls_playlist_type vod \
    -hls_segment_filename "${OUTPUT_DIR}/seg_%03d.ts" \
    "${OUTPUT_DIR}/index.m3u8"

echo "Done. HLS output:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "Add to your database (replace <duration> with the actual seconds):"
echo "  INSERT INTO videos (title, hls_path, duration_seconds)"
echo "  VALUES ('My Video', '/hls/$(basename "$OUTPUT_DIR")/index.m3u8', <duration>);"
