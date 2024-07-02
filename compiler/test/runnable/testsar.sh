#!/usr/bin/env bash

# create extra-files/archive.sar from extra-files/archive/sample.d
${DMD} -sar=${EXTRA_FILES}${SEP}archive

# ensure .sar file on command line works
${DMD} -m${MODEL} ${EXTRA_FILES}${SEP}testsar2.d ${EXTRA_FILES}${SEP}archive.sar -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

# ensure .sar file from import works
${DMD} -m${MODEL} ${EXTRA_FILES}${SEP}testsar1.d -I${EXTRA_FILES} -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

# remove generated .obj, .exe, and archive.sar files
rm ${OUTPUT_BASE}{${OBJ},${EXE}} ${EXTRA_FILES}${SEP}archive.sar

exit 0
