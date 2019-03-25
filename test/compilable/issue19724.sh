#! /usr/bin/env bash

if [[ $OS != linux ]]; then exit 0; fi

TEST_DIR=${OUTPUT_BASE}
# create two libraries with the first depending on the second
# so that if they're given the wrong order on the commandline,
# linking would ordinarily fail
D_LIBFILE1=$TEST_DIR/first.d
D_LIBFILE2=$TEST_DIR/second.d
D_LIB1=$TEST_DIR/libfirst.a
D_LIB2=$TEST_DIR/libsecond.a
# call from D
D_FILE=$TEST_DIR/test.d
APP=$TEST_DIR/test

mkdir -p $TEST_DIR

cat >$D_LIBFILE1 <<EOF
module first;
import second;

int first(int x) { return second.second(x); }
EOF

cat >$D_LIBFILE2 <<EOF
module second;

int second(int x) { return 0; }
EOF

cat >$D_FILE <<EOF
module test;

import first;

void main() {
    first.first(0);
}
EOF

${DMD} -m${MODEL} -lib -of${D_LIB1} -I${TEST_DIR} ${D_LIBFILE1}
${DMD} -m${MODEL} -lib -of${D_LIB2} -I${TEST_DIR} ${D_LIBFILE2}

# -lsecond -lfirst is wrong but for --start-group/--end-group,
# so --start-group and --end-group must not be reordered relative to the libraries
${DMD} -m${MODEL} -of${APP} ${D_FILE} -I${TEST_DIR} -L-L${TEST_DIR} -L=--start-group -L-lsecond -L-lfirst -L=--end-group
