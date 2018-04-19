
$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Single -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Double -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Extended -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

# needs PR 8169
# $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=ExtendedSoft ../src/dmd/root/longdouble.d -of${OUTPUT_BASE}${EXE}
# ${OUTPUT_BASE}${EXE}

