# Common bash variables exported to the bash script and bash post script of DMD's testsuite

if [ "${RESULTS_DIR+x}" == "" ]; then
    VARS_FILE="$DIR/../test_results/setup_env.sh"

    if [ -f "$VARS_FILE" ]
    then
        source "$VARS_FILE"
    else
        echo Note: this program is normally called through the Makefile, it
        echo is not meant to be called directly by the user.
        exit 1
    fi
fi

export TEST_DIR=$1 # TEST_DIR should be one of compilable, fail_compilation or runnable
export TEST_NAME=$2 # name of the test, e.g. test12345

export RESULTS_TEST_DIR=${RESULTS_DIR}/${TEST_DIR} # reference to the resulting test_dir folder, e.g .test_results/runnable
export OUTPUT_BASE=${RESULTS_TEST_DIR}/${TEST_NAME} # reference to the resulting files without a suffix, e.g. test_results/runnable/test123
export EXTRA_FILES=${TEST_DIR}/extra-files # reference to the extra files directory

export LC_ALL=C #otherwise objdump localizes its output

if [ "$OS" == "windows" ]; then
    export LIBEXT=.lib
else
    export LIBEXT=.a
fi

if [[ "$OS" == "win"* ]]; then
    export SOEXT=.dll
elif [[ "$OS" = "osx" ]]; then
    export SOEXT=.dylib
else
    export SOEXT=.so
fi

# Default to Microsoft cl on Windows
if [[ "$OS" == "win"* && -z "${CC+set}" ]] ; then
    CC="cl"
fi
export CC="${CC:-c++}" # C++ compiler to use
