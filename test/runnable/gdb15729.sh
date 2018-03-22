#!/usr/bin/env bash


src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable

libname=${dir}${SEP}lib15729${LIBEXT}

$DMD -g -m${MODEL} -I${src} -of${libname} -lib ${src}${SEP}lib15729.d
$DMD -g -m${MODEL} -I${src} -of${dir}${SEP}gdb15729${EXE} ${src}${SEP}gdb15729.d ${libname}

if [ $OS == "linux" ]; then
    cat > ${dir}${SEP}gdb15729.gdb <<-EOF
       b lib15729.d:16
       r
       echo RESULT=
       p s.val
EOF
    gdb ${dir}${SEP}gdb15729 --batch -x ${dir}${SEP}gdb15729.gdb | grep 'RESULT=.*1234'
fi

rm -f ${libname} ${dir}${SEP}{gdb15729${OBJ},gdb15729${EXE},gdb15729.gdb}
