#! /usr/bin/env bash

if [[ $OS = *"win"* ]]; then exit 0; fi

if [ $LIBEXT = ".a" ]; then
    LIB_PREFIX=lib
else
    LIB_PREFIX=
fi

TEST_DIR=${OUTPUT_BASE}
C_FILE=$TEST_DIR/square.c
C_LIB=$TEST_DIR/${LIB_PREFIX}csquare${LIBEXT}
D_FILE=$TEST_DIR/square.d
D_LIB=$TEST_DIR/${LIB_PREFIX}dsquare${LIBEXT}
APP_FILE=$TEST_DIR/app.d
APP=$TEST_DIR/app${EXE}

mkdir -p $TEST_DIR

cat >$C_FILE <<EOF
int square(int x) { return x*x; }
EOF

cat >$D_FILE <<EOF
module square;

extern(C) nothrow {
    int square (int x);
}

bool testSquare() {
    return square(2) == 4 && square(5) == 25;
}
EOF

cat >$APP_FILE <<EOF
module APP;

import square;

int main() {
    return testSquare() ? 0 : 1;
}
EOF

cc -m${MODEL} -c -o ${C_FILE}${OBJ} $C_FILE
ar rcs ${C_LIB} ${C_FILE}${OBJ}

${DMD} -m${MODEL} -lib -of${D_LIB} ${D_FILE}

${DMD} -m${MODEL} -of${APP} ${APP_FILE} -I${TEST_DIR} ${D_LIB} -L-L${TEST_DIR} -L-lcsquare

${APP}
