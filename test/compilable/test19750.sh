#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}/test19750.d <<EOF
import test19750b;
class Foo {
  import test19750a;
  void func (Bar ) {}
}
EOF

cat >${TEST_DIR}/test19750a.d <<EOF
import test19750c;
class Bar {} 
EOF

cat >${TEST_DIR}/test19750b.d <<EOF
import test19750d;
class Frop {}
EOF

cat >${TEST_DIR}/test19750c.d <<EOF
import test19750d;
class Qux: Thud {
  override void thunk() {}
}
EOF

cat >${TEST_DIR}/test19750d.d <<EOF
import test19750;
class Dap(T) {}
class Thud: Foo {
  Dap!int _dap;
  void thunk() { }
}
EOF

${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/${TEST_NAME}.d
rm -f ${TEST_DIR}/${TEST_NAME}.o ${TEST_DIR}/${TEST_NAME}*.d
