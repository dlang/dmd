#!/usr/bin/env bash

# -main doesn't work anymore when used for linking only (without source modules)
# https://issues.dlang.org/show_bug.cgi?id=22863

set -e

FOO=${OUTPUT_BASE}/foo${OBJ}

$DMD -m"${MODEL}" -c ${TEST_DIR}/testmain.d -of=$FOO
$DMD -m"${MODEL}" -main $FOO -of=${OUTPUT_BASE}/result
rm_retry -r ${OUTPUT_BASE}
