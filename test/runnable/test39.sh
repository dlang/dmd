#!/usr/bin/env bash



$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -c ${EXTRA_FILES}/test39.d

$DMD -m${MODEL} -I${TEST_DIR} -od${RESULTS_TEST_DIR} -c ${TEST_DIR}/imports/test39a.d
libname=${OUTPUT_BASE}a${LIBEXT}

if [ ${OS} == "windows" ]; then
    $DMD -m${MODEL} -lib -of${libname} ${OUTPUT_BASE}a${OBJ}
else
    ar -r ${libname} ${OUTPUT_BASE}a${OBJ}
fi

$DMD -m${MODEL} -of${OUTPUT_BASE}${EXE} ${OUTPUT_BASE}${OBJ} ${libname}

${OUTPUT_BASE}${EXE}

rm_retry ${OUTPUT_BASE}{${OBJ},a${OBJ},${EXE}} ${libname}