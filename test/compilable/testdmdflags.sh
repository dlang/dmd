#!/usr/bin/env bash

! $DMD -transitio | grep "Error: unrecognized switch '-transitio'"
! $DMD -transition=he | grep "Error: unrecognized switch '-transition=he'"

for w in "transition" "transition=" "transition=?" "transition=h" "transition=help" ; do
    $DMD "-${w}" | grep "Language changes listed by -transition=id:"
done

! $DMD -mcp | grep "Error: unrecognized switch '-mcp'"
! $DMD -mcpu=he | grep "Error: unrecognized switch '-mcpu=he'"

for w in "mcpu" "mcpu=" "mcpu=?" "mcpu=h" "mcpu=help" ; do
    $DMD "-${w}" | grep "CPU architectures supported by -mcpu=id:"
done
