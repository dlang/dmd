#!/usr/bin/env bash



$DMD -g -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${LIBEXT} -lib ${EXTRA_FILES}${SEP}lib15729.d
$DMD -g -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}${SEP}gdb15729.d ${OUTPUT_BASE}${LIBEXT}

if [ $OS == "linux" ]; then
    cat > ${OUTPUT_BASE}.gdb <<-EOF
       b lib15729.d:16
       r
       echo RESULT=
       p s.val
EOF
    gdb ${OUTPUT_BASE}${EXE} --batch -x ${OUTPUT_BASE}.gdb | grep 'RESULT=.*1234'
fi

rm_retry -f ${OUTPUT_BASE}{,${OBJ},${EXE},${LIBEXT},.gdb}
