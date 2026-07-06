#!/bin/sh

SCAN_ROOT="/"
EXCLUDE_DIRS="/proc /sys /dev /tmp /run /mnt /media"
TEMP_LIST="/tmp/file_list_$$.txt"
MD5_FILE="/tmp/md5_list_$$.txt"
SHA256_FILE="/tmp/sha256_list_$$.txt"

trap 'echo ""; echo "Stopped by user. Cleaning up..."; rm -f "$TEMP_LIST" "$MD5_FILE" "$SHA256_FILE"; exit 0' INT

echo "Heavy load test started. Press Ctrl+C to stop."

while true; do
    PASS=$((PASS + 1))
    echo ""
    echo "=== PASS $PASS ==="

    find "$SCAN_ROOT" -type f 2>/dev/null > "$TEMP_LIST"

    for excl in $EXCLUDE_DIRS; do
        sed -i "\#^$excl#d" "$TEMP_LIST" 2>/dev/null
    done

    TOTAL_FILES=$(wc -l < "$TEMP_LIST" 2>/dev/null)
    CURRENT=0
    > "$MD5_FILE"
    > "$SHA256_FILE"

    while IFS= read -r filepath; do
        CURRENT=$((CURRENT + 1))
        if [ $((CURRENT % 100)) -eq 0 ]; then
            echo "Pass $PASS: Processed $CURRENT of $TOTAL_FILES files..."
        fi

        if [ -f "$filepath" ] && [ -r "$filepath" ]; then
            md5=$(md5sum "$filepath" 2>/dev/null | awk '{print $1}')
            sha256=$(sha256sum "$filepath" 2>/dev/null | awk '{print $1}')

            if [ -n "$md5" ] && [ -n "$sha256" ]; then
                md5_of_md5=$(echo -n "$md5" | md5sum | awk '{print $1}')
                sha256_of_sha256=$(echo -n "$sha256" | sha256sum | awk '{print $1}')
                combined_hash=$(echo -n "${md5}${sha256}" | md5sum | awk '{print $1}')

                echo "$md5_of_md5  $filepath" >> "$MD5_FILE"
                echo "$sha256_of_sha256  $filepath" >> "$SHA256_FILE"
                echo "$combined_hash  $filepath" >> /tmp/combined_$$.tmp
            fi
        fi
    done < "$TEMP_LIST"

    echo "Pass $PASS complete."
    echo "  MD5-of-MD5 entries: $(wc -l < "$MD5_FILE")"
    echo "  SHA256-of-SHA256 entries: $(wc -l < "$SHA256_FILE")"
    echo "  Combined hash entries: $(wc -l < /tmp/combined_$$.tmp 2>/dev/null)"

    rm -f /tmp/combined_$$.tmp
done