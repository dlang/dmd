#!/usr/bin/env bash

# redirecting stderr to nirvana saves ~30 secs on Windows...
! $DMD -c ${EXTRA_FILES}/fail12485.d 2> /dev/null
