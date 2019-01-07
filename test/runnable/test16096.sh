#!/usr/bin/env bash


if [ "$OS" != 'osx' ] || [ "$MODEL" != '64' ]; then
    exit 0
fi

$DMD -I${EXTRA_FILES} -of${OUTPUT_BASE}${LIBEXT} -lib ${EXTRA_FILES}/test16096a.d
$DMD -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} ${EXTRA_FILES}/test16096.d ${OUTPUT_BASE}${LIBEXT} -L-framework -LFoundation
${OUTPUT_BASE}${EXE}

rm ${OUTPUT_BASE}{${LIBEXT},${EXE}}
