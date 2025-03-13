#!/bin/bash
set -euxo pipefail

OLD_OUTPUT=$1
NEW_OUTPUT=$2

echo "Build Statistics Diff (from summary_comment_diff.sh):"

# Compare each STAT: line in NEW_OUTPUT against OLD_OUTPUT.
while IFS= read -r new_line; do
    # Process only lines that start with "STAT:"
    if [[ $new_line != STAT:* ]]; then
        continue
    fi
    # Extract the key and new value.
    key=$(echo "$new_line" | cut -d':' -f2 | cut -d'=' -f1)
    new_value=$(echo "$new_line" | cut -d'=' -f2-)
    # Find the matching line in OLD_OUTPUT.
    old_line=$(grep "^STAT:${key}=" "$OLD_OUTPUT" || echo "")
    if [ -z "$old_line" ]; then
        echo "New stat '$key' added: $new_value"
    else
        old_value=$(echo "$old_line" | cut -d'=' -f2-)
        if [ "$new_value" != "$old_value" ]; then
            echo "Stat '$key' changed: old value: $old_value, new value: $new_value"
        fi
    fi
done < "$NEW_OUTPUT"

# Also, report any stats that existed in OLD_OUTPUT but are missing in NEW_OUTPUT.
while IFS= read -r old_line; do
    if [[ $old_line != STAT:* ]]; then
        continue
    fi
    key=$(echo "$old_line" | cut -d':' -f2 | cut -d'=' -f1)
    if ! grep -q "^STAT:${key}=" "$NEW_OUTPUT"; then
        old_value=$(echo "$old_line" | cut -d'=' -f2-)
        echo "Stat '$key' removed. Previous value: $old_value"
    fi
done < "$OLD_OUTPUT"
