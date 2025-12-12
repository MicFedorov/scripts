#!/bin/bash
set -euo pipefail

# --- Helpers ---
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

abort() {
    echo "ERROR: $*" | tee -a "$LOGFILE"
    exit 1
}

# --- Args ---
SRC="${1:-}"
DST="${2:-}"

if [[ -z "$SRC" || -z "$DST" ]]; then
    echo "Usage: $0 <SRC_DIR> <DST_DIR>"
    exit 1
fi

# Remove trailing slashes
SRC="${SRC%/}"
DST="${DST%/}"

# --- Validate paths ---
[[ -d "$SRC" ]] || abort "Source not found: $SRC"
[[ -d "$DST" ]] || abort "Destination not found: $DST"

# --- Derive names for report directory ---
# SRC = /mnt/olimbos/SCAN_OLD_PHOTOS
# parent = olimbos
# DST = /mnt/throni/SCAN_OLD_PHOTOS
# parent = throni

SRC_PARENT=$(basename "$(dirname "$SRC")")
DST_PARENT=$(basename "$(dirname "$DST")")

# Timestamp without ':' for safety
NOW=$(date '+%Y-%m-%d-%H-%M-%S')

OUTDIR="./report_${SRC_PARENT}_${DST_PARENT}_${NOW}"
LOGFILE="${OUTDIR}/run.log"

mkdir -p "$OUTDIR" || abort "Cannot create report directory: $OUTDIR"

log "=== START safe_hash_compare ==="
log "SRC = $SRC"
log "DST = $DST"
log "OUTDIR = $OUTDIR"

SRC_HASH="$OUTDIR/src.hashes.bin"
DST_HASH="$OUTDIR/dst.hashes.bin"

# --- Generate hashes ---
log "Generating hashes for $SRC → $SRC_HASH"
find "$SRC" -type f -print0 \
    | sort -z \
    | xargs -0 sha256sum > "$SRC_HASH"

log "Generating hashes for $DST → $DST_HASH"
find "$DST" -type f -print0 \
    | sort -z \
    | xargs -0 sha256sum > "$DST_HASH"

# --- Compare simple file names ---
log "Comparing file lists..."

SRC_LIST="$OUTDIR/src.list"
DST_LIST="$OUTDIR/dst.list"

find "$SRC" -type f | sed "s|$SRC/||" | sort > "$SRC_LIST"
find "$DST" -type f | sed "s|$DST/||" | sort > "$DST_LIST"

comm -23 "$SRC_LIST" "$DST_LIST" > "$OUTDIR/only_in_src.txt"
comm -13 "$SRC_LIST" "$DST_LIST" > "$OUTDIR/only_in_dst.txt"

log "Files only in SRC: $(wc -l < "$OUTDIR/only_in_src.txt")"
log "Files only in DST: $(wc -l < "$OUTDIR/only_in_dst.txt")"

# --- Deep compare (hash differences) ---
log "Comparing hashes..."

# Normalize hash output to: HASH␣RELATIVE_PATH
sed "s|  $SRC/|  |" "$SRC_HASH" | sort > "$OUTDIR/src.norm"
sed "s|  $DST/|  |" "$DST_HASH" | sort > "$OUTDIR/dst.norm"

comm -23 "$OUTDIR/src.norm" "$OUTDIR/dst.norm" > "$OUTDIR/hash_diff_src.txt"
comm -13 "$OUTDIR/src.norm" "$OUTDIR/dst.norm" > "$OUTDIR/hash_diff_dst.txt"

log "Files with different hashes (SRC vs DST): $(wc -l < "$OUTDIR/hash_diff_src.txt")"
log "Files with different hashes (DST vs SRC): $(wc -l < "$OUTDIR/hash_diff_dst.txt")"

log "=== DONE ==="
