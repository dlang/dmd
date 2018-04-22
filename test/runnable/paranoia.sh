
echo ======== Testing Single Precision ========
$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Single -of${OUTPUT_BASE}_1${EXE}
${OUTPUT_BASE}_1${EXE}

echo ======== Testing Double Precision ========
$DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Double -of${OUTPUT_BASE}_2${EXE}
${OUTPUT_BASE}_2${EXE}

if [ "${OS}" == "win64" -o "${MODEL}" == "32mscoff" ]; then
    echo ======== Testing Extended Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Extended ../src/dmd/root/longdouble.d -of${OUTPUT_BASE}_3${EXE}
    ${OUTPUT_BASE}_3${EXE}

    echo ======== Testing ExtendedSoft Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=ExtendedSoft ../src/dmd/root/longdouble.d -of${OUTPUT_BASE}_4${EXE}
    ${OUTPUT_BASE}_4${EXE}
else
    echo ======== Testing Extended Precision ========
    $DMD -m${MODEL} ${EXTRA_FILES}/paranoia.d -version=Extended -of${OUTPUT_BASE}_3${EXE}
    ${OUTPUT_BASE}_3${EXE}
fi

echo ======== Testing CTFE Single Precision ========
$DMD -m${MODEL} -c -o- ${EXTRA_FILES}/paranoia.d -version=Single -version=CTFE

echo ======== Testing CTFE Double Precision ========
$DMD -m${MODEL} -c -o- ${EXTRA_FILES}/paranoia.d -version=Double -version=CTFE

echo ======== Testing CTFE Extended Precision ========
$DMD -m${MODEL} -c -o- ${EXTRA_FILES}/paranoia.d -version=Extended -version=CTFE

rm ${OUTPUT_BASE}_[1-4]${EXE}
rm ${OUTPUT_BASE}_[1-4]${OBJ}
