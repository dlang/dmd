#!/usr/bin/env bash

name=`basename $0 .sh`
dir=${RESULTS_DIR}/compilable
src=compilable/extra-files

$DMD -c -m${MODEL} -of${dir}/${name}a${OBJ} -I${src} ${src}/${name}a.d || exit 1

$DMD -unittest -m${MODEL} -od${dir} -I${src} ${src}/${name}main.d ${dir}/${name}a${OBJ} || exit 1

rm -f ${dir}/{${name}a${OBJ} ${name}main${EXE} ${name}main${OBJ}}

echo Success >${dir}/`basename $0`.out
