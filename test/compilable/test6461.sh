#!/usr/bin/env bash

dir=${RESULTS_DIR}/compilable
src=compilable/extra-files/${TEST_NAME}

if [ "${OS}" == "win32" -o "${OS}" == "win64" ]; then
    LIBEXT=.lib
else
    LIBEXT=.a
fi

$DMD -lib -m${MODEL} -of${dir}/a${LIBEXT} -I${src} ${src}/a.d || exit 1
$DMD -lib -m${MODEL} -of${dir}/b${LIBEXT} -I${src} ${src}/b.d || exit 1

$DMD -m${MODEL} -od${dir} -I${src} ${src}/main.d ${dir}/a${LIBEXT} ${dir}/b${LIBEXT} || exit 1

rm -f ${dir}/{a${LIBEXT} b${LIBEXT} main${EXE} main${OBJ}}

echo Success
