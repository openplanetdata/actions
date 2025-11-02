#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: r2-upload.sh [--allow-missing] [--label LABEL] [--progress] [--suffix SUFFIX] REMOTE_NAME REMOTE_BUCKET REMOTE_PATH REMOTE_VERSION REMOTE_FILENAME SOURCE

Uploads SOURCE to the R2 remote at REMOTE_NAME:REMOTE_BUCKET, building the destination key as
REMOTE_PATH/REMOTE_VERSION/REMOTE_FILENAME plus any SUFFIX provided.

Options:
  --allow-missing   Skip the upload if SOURCE does not exist.
  --label LABEL     Human friendly description used when reporting missing files.
  --progress        Enable rclone progress output.
  --suffix SUFFIX   Append SUFFIX to the remote filename (e.g., ".metadata").
  -h, --help        Show this help message.
EOF
}

allow_missing=false
label=""
progress=false
suffix=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-missing)
      allow_missing=true
      shift
      ;;
    --label)
      [[ $# -ge 2 ]] || { echo "Missing value for --label" >&2; exit 1; }
      label="$2"
      shift 2
      ;;
    --progress)
      progress=true
      shift
      ;;
    --suffix)
      [[ $# -ge 2 ]] || { echo "Missing value for --suffix" >&2; exit 1; }
      suffix="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ne 6 ]]; then
  echo "Expected 6 positional arguments, got $#." >&2
  usage >&2
  exit 1
fi

remote_name="$1"
remote_bucket="$2"
remote_path="$3"
remote_version="$4"
remote_filename="$5"
source_path="$6"

if [[ ! -f "$source_path" ]]; then
  if $allow_missing; then
    readable="${label:-file}"
    echo "No ${readable} found at $source_path; skipping upload."
    exit 0
  fi
  echo "Source file not found: $source_path" >&2
  exit 1
fi

if [[ -z "$remote_filename" ]]; then
  remote_filename="$(basename "$source_path")"
fi

normalize_segment() {
  local segment="$1"
  segment="${segment#/}"
  segment="${segment%/}"
  printf '%s' "$segment"
}

segments=()
for segment in "$remote_path" "$remote_version"; do
  normalized="$(normalize_segment "$segment")"
  if [[ -n "$normalized" ]]; then
    segments+=("$normalized")
  fi
done

if [[ ${#segments[@]} -gt 0 ]]; then
  base_path="$(printf '%s/' "${segments[@]}")"
  base_path="${base_path%/}"
  object_path="$base_path/$remote_filename$suffix"
else
  object_path="$remote_filename$suffix"
fi

object_path="${object_path#/}"

if $progress; then
  # Use --stats-log-level to output stats to logs without carriage returns
  # Also set --log-level INFO to ensure stats messages are actually logged
  rclone copyto --stats=60s --stats-one-line-date --stats-log-level INFO --log-level INFO \
    --buffer-size=512M \
    --multi-thread-cutoff 0 \
    --multi-thread-streams 64 \
    --multi-thread-chunk-size 512M \
    --s3-upload-concurrency=128 \
    --s3-chunk-size=128M \
    --transfers=1 \
    "$source_path" \
    "${remote_name}:${remote_bucket}/$object_path"
else
  rclone copyto "$source_path" "${remote_name}:${remote_bucket}/$object_path"
fi
