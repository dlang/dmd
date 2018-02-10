#!/usr/bin/env bash

set -ueo pipefail

TEMP_LIB_PATH=${RESULTS_DIR}${SEP}compilable${SEP}templibpath

function echorun() {
    echo $@
    $@
}

if [ $OS == "win32" -o  $OS == "win64" ]; then
    LIB_ARGS=
    FOOLIB_OUT=foolib.lib
    FOOLIB_ARG=foolib.lib
    # TODO: if MSVC; then
    #    LINKER_FLAG=/LIBPATH:${TEMP_LIB_PATH}
    LINKER_FLAG="-L+${TEMP_LIB_PATH}\\"
else
    LIB_ARGS=-fPIC
    FOOLIB_OUT=libfoolib.a
    FOOLIB_ARG=-L-lfoolib
    LINKER_FLAG=-L-L${TEMP_LIB_PATH}
fi

mkdir -p ${TEMP_LIB_PATH}

echorun ${DMD} -m${MODEL} -conf= -lib ${LIB_ARGS} -od${TEMP_LIB_PATH} -of${FOOLIB_OUT} compilable/extra-files/foolib.d

# TODO: remove -v before merging
echorun ${DMD} -v -m${MODEL} -conf= -od${TEMP_LIB_PATH} -of${TEMP_LIB_PATH}/libpath -Icompilable/extra-files compilable/extra-files/libpath.d ${LINKER_FLAG} ${FOOLIB_ARG}

rm -rf ${TEMP_LIB_PATH}
