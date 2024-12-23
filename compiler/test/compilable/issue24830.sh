#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}
# create two modules each depending on each other.
# They both do the same template instantiation.
D_FILE1=$TEST_DIR/first.d
D_FILE2=$TEST_DIR/second.d
D_OBJ1=$TEST_DIR/first${OBJ}
D_OBJ2=$TEST_DIR/second${OBJ}
APP=$TEST_DIR/app

mkdir -p $TEST_DIR

cat >$D_FILE1 <<EOF
module first;
import second;

struct S(T) {
    int opCmp()(const(S) rhs) const { return 0; }
}
S!int f;
EOF

cat >$D_FILE2 <<EOF
module second;
import first;
S!int s;
EOF

${DMD} -m${MODEL} -c -of${D_OBJ1} -I${TEST_DIR} ${D_FILE1}
${DMD} -m${MODEL} -c -of${D_OBJ2} -I${TEST_DIR} ${D_FILE2}

# Try to link them
${DMD} -main -m${MODEL} -of${APP} ${D_OBJ1} ${D_OBJ2}
