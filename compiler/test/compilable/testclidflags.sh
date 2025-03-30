#!/usr/bin/env bash

# Windows-WSL: Export DFLAGS s.t. the windows executable sees the required changes
export WSLENV="DFLAGS"

unset DFLAGS

# Force DMD to print the -v menu by passing an invalid object file
# It will fail with "no object files to link", but print the log
# On OSX DMD terminates with a successful exit code, so `|| true` is used.
( "$DMD" -conf= -v foo.d 2> /dev/null || true) | grep -q "DFLAGS    (none)"
( DFLAGS="-O -D" "$DMD" -conf= -v foo.d 2> /dev/null || true) | grep -q "DFLAGS    -O -D"
( DFLAGS="-O '-Ifoo bar' -c" "$DMD" -conf= -v foo.d 2> /dev/null || true) | grep -q "DFLAGS    -O '-Ifoo bar' -c"
