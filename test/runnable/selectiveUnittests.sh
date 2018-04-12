#!/usr/bin/env bash

obj_file=${OUTPUT_BASE}/tempobj${OBJ}
exe_file=${OUTPUT_BASE}/tempexe${EXE}

# Compile both modules, make sure unittest compiles/runs
unittest_output="unittesting printingUnittest"
$DMD -m${MODEL} -of=${exe_file} -I=${EXTRA_FILES} -unittest ${EXTRA_FILES}/printingUnittest.d ${EXTRA_FILES}/selectiveUnittests.d
${exe_file} | grep -q "${unittest_output}"
./runnable/extra-files/check_bin.sh ${exe_file} HAS __unittest

# Precompile the module and make sure it's unittest doesn't get compiled/run
$DMD -m${MODEL} -c -of=${obj_file} ${EXTRA_FILES}/printingUnittest.d
./runnable/extra-files/check_bin.sh ${exe_file} DOES_NOT_HAVE __unittest

rm -f ${exe_file}
$DMD -m${MODEL} -of=${exe_file} -I=${EXTRA_FILES} -unittest ${obj_file} ${EXTRA_FILES}/selectiveUnittests.d
${exe_file} | grep -q -v "${unittest_output}"

# Make sure that version(unittest) still get analyzed
unittest_output="version unittest"
$DMD -m${MODEL} -I=${EXTRA_FILES} -o- -unittest ${EXTRA_FILES}/printVersionUnittest.d ${EXTRA_FILES}/selectiveUnittests2.d 2>&1 | grep -q "${unittest_output}"

# Precompile the module and make sure version(unittest) is still enabled
$DMD -m${MODEL} -c -of=${obj_file} ${EXTRA_FILES}/printVersionUnittest.d
$DMD -m${MODEL} -I=${EXTRA_FILES} -o- -unittest ${obj_file} ${EXTRA_FILES}/selectiveUnittests2.d 2>&1 | grep -q "${unittest_output}"

rm -f ${obj_file}
rm -f ${exe_file}
