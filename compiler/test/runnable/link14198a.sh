#!/usr/bin/env bash


libname=${OUTPUT_BASE}${LIBEXT}


# build library
$DMD -m${MODEL} -I${EXTRA_FILES} -of${libname} -lib ${EXTRA_FILES}${SEP}std14198${SEP}array.d ${EXTRA_FILES}${SEP}std14198${SEP}conv.d ${EXTRA_FILES}${SEP}std14198${SEP}format.d ${EXTRA_FILES}${SEP}std14198${SEP}uni.d

# Do not link failure with library file, regardless the semantic order.
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE}                   ${EXTRA_FILES}${SEP}test14198.d ${libname}
$DMD -m${MODEL} -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE} -version=bug14198 ${EXTRA_FILES}${SEP}test14198.d ${libname}

rm_retry ${OUTPUT_BASE}{${OBJ},${EXE}} ${libname}
