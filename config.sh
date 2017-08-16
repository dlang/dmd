#!/bin/sh

set -ue

OUTDIR="$1"
VERSIONFILE="$2"
SYSCONFDIR="$3"
VERSION=$(git describe --dirty 2>/dev/null || cat "$VERSIONFILE") # prefer git describe

mkdir -p "$OUTDIR"
# only update config files when they actually differ to avoid unnecessary rebuilds
if [ "$VERSION" != "$(cat "$OUTDIR/VERSION" 2>/dev/null)" ]; then
    printf "$VERSION" > "$OUTDIR/VERSION"
fi
if [ "$SYSCONFDIR" != "$(cat "$OUTDIR/SYSCONFDIR.imp" 2>/dev/null)" ]; then
    printf "$SYSCONFDIR" > "$OUTDIR/SYSCONFDIR.imp"
fi
