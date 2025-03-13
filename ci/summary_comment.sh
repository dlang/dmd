#!/bin/bash
set -euxo pipefail

# Output the build date/time
echo "STAT:build date=$(date '+%Y-%m-%d %H:%M:%S')"

# Output rough build time.
# Expects that the workflow has set RUNTIME in milliseconds.
if [ -n "${RUNTIME:-}" ]; then
    runtime_sec=$(awk "BEGIN {printf \"%.3f\", $RUNTIME/1000}")
    echo "STAT:rough build time=${runtime_sec}s ($RUNTIME ms)"
else
    echo "STAT:rough build time=unknown"
fi

# Output RAM usage.
if [ -n "${RAM_USAGE:-}" ]; then
    echo "STAT:RAM usage=${RAM_USAGE} MB"
else
    echo "STAT:RAM usage=unknown"
fi

# Output the executable size if the file exists.
if [ -f "bin/dub" ]; then
    exe_size=$(stat -c%s "bin/dub")
    echo "STAT:executable size=${exe_size} bytes (bin/dub)"
else
    echo "STAT:executable size=not found"
fi

# Parse warnings and deprecations from the full build log.
# This assumes that warnings have the word "warning:" and deprecations have "deprecated:".
if [ -f "FULL_OUTPUT.txt" ]; then
    warnings=$(grep -i "warning:" FULL_OUTPUT.txt | wc -l)
    deprecations=$(grep -i "deprecated:" FULL_OUTPUT.txt | wc -l)
    echo "STAT:total warnings=${warnings}"
    echo "STAT:total deprecations=${deprecations}"
else
    echo "STAT:total warnings=unknown"
    echo "STAT:total deprecations=unknown"
fi
