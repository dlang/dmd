#!/usr/bin/env bash

if [[ $OS = "wasm" ]]; then
    exit 0
fi

if [[ $OS = "win"* ]]; then
    for tool in nm objdump; do
        if ! which -s $tool; then
            echo "No '$tool' tool found in PATH, skipping symbols verification on Windows."
            exit 0
        fi
    done
fi

obj_file="${RESULTS_TEST_DIR}/d/${TEST_NAME}_0${OBJ}"

# ensure no ModuleInfo or TypeInfo related code was generated
if nm "${obj_file}" | { ! grep -q 'ModuleInfo\|_d_dso_registry\__start_minfo\|__stop_minfo\|TypeInfo'; } ; then
    # ensure no exception handling code was generated
    if objdump -h "${obj_file}" | { ! grep -q ".eh_frame"; } ; then
        exit 0
    fi
fi

exit 1
