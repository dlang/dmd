
echo ======== Testing Single Precision ========
$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Single -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

echo ======== Testing Double Precision ========
$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Double -of${OUTPUT_BASE}${EXE}
${OUTPUT_BASE}${EXE}

if [ "PR" == "8169" ]; then
# needs PR 8169
# if [ "${OS}" == "win64" -o "${MODEL}" == "32mscoff" ]; then
    echo ======== Testing Extended Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Extended ../src/dmd/root/longdouble.d -of${OUTPUT_BASE}${EXE}
    ${OUTPUT_BASE}${EXE}

    echo ======== Testing ExtendedSoft Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=ExtendedSoft ../src/dmd/root/longdouble.d -of${OUTPUT_BASE}${EXE}
    ${OUTPUT_BASE}${EXE}
else
    echo ======== Testing Extended Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Extended -of${OUTPUT_BASE}${EXE}
    ${OUTPUT_BASE}${EXE}
fi

echo ======== Testing CTFE Single Precision ========
$DMD -m${MODEL} -c ${EXTRA_FILES}/paranoia.d -version=Single -version=CTFE -of${OUTPUT_BASE}${EXE}

echo ======== Testing CTFE Double Precision ========
$DMD -m${MODEL} -c ${EXTRA_FILES}/paranoia.d -version=Double -version=CTFE -of${OUTPUT_BASE}${EXE}

echo ======== Testing CTFE Extended Precision ========
$DMD -m${MODEL} -c ${EXTRA_FILES}/paranoia.d -version=Extended -version=CTFE -of${OUTPUT_BASE}${EXE}
