#!/usr/bin/env bash

set -e

dir=${RESULTS_DIR}/compilable
src=compilable/extra-files/${TEST_NAME}

$DMD -lib -m${MODEL} -of${dir}/a${LIBEXT} -I${src} ${src}/a.d
$DMD -lib -m${MODEL} -of${dir}/b${LIBEXT} -I${src} ${src}/b.d

$DMD -m${MODEL} -od${dir} -I${src} ${src}/main.d ${dir}/a${LIBEXT} ${dir}/b${LIBEXT}

rm -f ${dir}/{a${LIBEXT} b${LIBEXT} main${EXE} main${OBJ}}
