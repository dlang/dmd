#!/usr/bin/env bash

mkdir -p $OUTPUT_BASE
export DFLAGS=$(echo $DFLAGS | sed -E 's/-defaultlib=[^ ]*/-defaultlib=/')
set +u
BOUND_PIC_FLAG="$PIC_FLAG"
set -u
$DMD -m$MODEL -shared $BOUND_PIC_FLAG -of$OUTPUT_BASE/libdefaultlib$SOEXT -defaultlib= $EXTRA_FILES${SEP}defaultlib.d

echo 'pragma(lib, "defaultlib");' > $OUTPUT_BASE/_defaultlibconf.d

extra_args=""
if [ "$OS" == "linux" ] || [ "$OS" == "freebsd" ]; then
    extra_args+=" -L-rpath=$(realpath $OUTPUT_BASE)"
fi
export DFLAGS=$(echo $DFLAGS | sed -E 's/-defaultlib=[^ ]*//')
$DMD -m$MODEL -conf= $BOUND_PIC_FLAG -of$OUTPUT_BASE/use$EXE $EXTRA_FILES${SEP}usedefaultlib.d -L-L$OUTPUT_BASE  -I=$TEST_DIR/extra-files $extra_args

$OUTPUT_BASE/use$EXE
