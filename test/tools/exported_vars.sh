# Common bash variables exported to the bash script and bash post script of DMD's testsuite

export TEST_DIR=$1 # TEST_DIR should be one of compilable, fail_compilation or runnable
export TEST_NAME=$2 # name of the test, e.g. test12345

export RESULTS_TEST_DIR=${RESULTS_DIR}/${TEST_DIR} # reference to the resulting test_dir folder, e.g .test_results/runnable
export OUTPUT_BASE=${RESULTS_TEST_DIR}/${TEST_NAME} # reference to the resulting files without a suffix, e.g. test_results/runnable/test123
export EXTRA_FILES=${TEST_DIR}/extra-files # reference to the extra files directory

if [ "$OS" == "win32" ] || [ "$OS" == "win64" ]; then
    export LIBEXT=.lib
else
    export LIBEXT=.a
fi

# Default to DigitalMars C++ on Win32
if [ "$OS" == "win32" ] && [ -z "${CC+set}" ] ; then
    CC="dmc"
fi
export CC="${CC:-c++}" # C++ compiler to use
