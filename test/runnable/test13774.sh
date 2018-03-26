#!/usr/bin/env bash

set -e

$DMD -m${MODEL} -I${EXTRA_FILES} -lib -of${OUTPUT_BASE}a${LIBEXT} ${EXTRA_FILES}${SEP}lib13774a.d
$DMD -m${MODEL} -I${EXTRA_FILES} -lib -of${OUTPUT_BASE}b${LIBEXT} ${EXTRA_FILES}${SEP}lib13774b.d ${OUTPUT_BASE}a${LIBEXT}

rm ${OUTPUT_BASE}{a${LIBEXT},b${LIBEXT}}