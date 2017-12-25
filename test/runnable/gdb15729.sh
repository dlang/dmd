#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/gdb15729.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	LIBEXT=.lib
else
	LIBEXT=.a
fi
libname=${dir}${SEP}lib15729${LIBEXT}

$DMD -g -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}lib15729.d || exit 1
$DMD -g -m${MODEL} -I${src} -of${dir}${SEP}gdb15729${EXE} ${src}${SEP}gdb15729.d ${libname} || exit 1

if [ $OS == "linux" ]; then
    cat > ${dir}${SEP}gdb15729.gdb <<-EOF
       b lib15729.d:16
       r
       echo RESULT=
       p s.val
EOF
    gdb ${dir}${SEP}gdb15729 --batch -x ${dir}${SEP}gdb15729.gdb | grep 'RESULT=.*1234' || exit 1
fi

rm -f ${libname} ${dir}${SEP}{gdb15729${OBJ},gdb15729${EXE},gdb15729.gdb}

echo Success >${output_file}
