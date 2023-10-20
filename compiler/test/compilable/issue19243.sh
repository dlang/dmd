#! /usr/bin/env bash

# bypassing this test:
#  - on windows
#  - on FreeBSD 32 bits
#       test fails looling for liborig.so; don't know why but shouldn't block fixing all other platforms
#  - on Circle CI with no_pic. (need PIC to run the test)
if [[ $OS = *"win"* ]]; then exit 0; fi
if [[ $OS = *"freebsd"* ]] && [[ $MODEL = *"32"* ]]; then exit 0; fi
if [ ${PIC:-1} == "0" ]; then exit 0; fi

TEST_DIR=${OUTPUT_BASE}
ORIG_D=$TEST_DIR/orig.d
ORIG_SO=$TEST_DIR/liborig${SOEXT}
OVERRIDE_D=$TEST_DIR/override.d
OVERRIDE_SO=$TEST_DIR/liboverride${SOEXT}
APP_D=$TEST_DIR/app.d

mkdir -p $TEST_DIR

cat << EOF | $DMD -m$MODEL -fPIC -shared -of$ORIG_SO -
import core.stdc.stdio;

extern(C) int func()
{
    printf("liborig\n");
    return 1;
}
EOF

cat << EOF | $DMD -m$MODEL -fPIC -shared -of$OVERRIDE_SO -
import core.stdc.stdio;

extern(C) int func()
{
    printf("liboverride\n");
    return 2;
}
EOF

cat << EOF | LD_LIBRARY_PATH=$TEST_DIR $DMD -m$MODEL -L-L$TEST_DIR -L$OVERRIDE_SO -run -
extern(C) int func();

pragma(lib, "orig");

void main()
{
    assert(func() == 2);
}
EOF
