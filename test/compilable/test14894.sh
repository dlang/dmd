#!/usr/bin/env bash

set -e

dir=${RESULTS_DIR}/compilable
src=compilable/extra-files

$DMD -c -m${MODEL} -of${dir}/${TEST_NAME}a${OBJ} -I${src} ${src}/${TEST_NAME}a.d

$DMD -unittest -m${MODEL} -od${dir} -I${src} ${src}/${TEST_NAME}main.d ${dir}/${TEST_NAME}a${OBJ}

rm -f ${dir}/{${TEST_NAME}a${OBJ} ${TEST_NAME}main${EXE} ${TEST_NAME}main${OBJ}}
