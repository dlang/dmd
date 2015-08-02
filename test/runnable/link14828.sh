#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}${SEP}link14828.sh.out

rm -f ${output_file}

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi

srcname=${src}${SEP}link14828
outname=${dir}${SEP}link14828

libname=${outname}x${LIBEXT}
exename=${outname}y${EXE}

# all0_order_flipped:
$DMD -m${MODEL} -I${src} -of${libname} -lib -g ${srcname}c.d ${srcname}a.d ${srcname}b.d || exit 1
$DMD -m${MODEL} -I${src} -of${exename}      -g ${libname}    ${srcname}a.d ${srcname}d.d || exit 1
${dir}/link14828y || exit 1

# all0:
$DMD -m${MODEL} -I${src} -of${libname} -lib -g ${srcname}c.d ${srcname}b.d ${srcname}a.d || exit 1
$DMD -m${MODEL} -I${src} -of${exename}      -g ${libname}    ${srcname}a.d ${srcname}d.d || exit 1
${dir}/link14828y || exit 1

# all1:
$DMD -m${MODEL} -I${src} -of${libname} -lib -g ${srcname}c.d ${srcname}a.d ${srcname}b.d || exit 1
$DMD -m${MODEL} -I${src} -of${exename}      -g ${libname}    ${srcname}b.d ${srcname}d.d || exit 1
${dir}/link14828y || exit 1

# all1_order_flipped:
$DMD -m${MODEL} -I${src} -of${libname} -lib -g ${srcname}c.d ${srcname}b.d ${srcname}a.d || exit 1
$DMD -m${MODEL} -I${src} -of${exename}      -g ${libname}    ${srcname}b.d ${srcname}d.d || exit 1
${dir}/link14828y || exit 1

rm ${libname} ${exename} ${outname}y${OBJ}

echo Success > ${output_file}
