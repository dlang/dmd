#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/link15906.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}lib15906${LIBEXT}

# build library
$DMD -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}std15906${SEP}algo.d ${src}${SEP}std15906${SEP}file.d || exit 1

# build executable, needs -g to repruduce link-failure in win32
$DMD -m${MODEL} -I${src} -g -of${dir}${SEP}test15906${EXE} ${src}${SEP}test15906.d ${libname} || exit 1

rm ${libname}
rm ${dir}/{test15906${OBJ},test15906${EXE}}

echo Success > ${output_file}
