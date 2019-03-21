#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}${SEP}test19657a.d <<EOF
import test19657c;
import test19657e: Bar;
class Foo {
  int[Foo] _map;
  bool func (Foo rhs, Bar bee) { return true; }
}
EOF

cat >${TEST_DIR}${SEP}test19657b.d <<EOF
import test19657g;
import test19657a;
import test19657e;
class Frop: Seq {
  override bool func(Foo rhs, Bar bee) { return false; }
}
EOF

cat >${TEST_DIR}${SEP}test19657c.d <<EOF
import test19657a;
class Pol: Foo {}
EOF

cat >${TEST_DIR}${SEP}test19657d.d <<EOF
import test19657a;
class Trump: Foo {}
EOF

cat >${TEST_DIR}${SEP}test19657e.d <<EOF
import test19657f;
class Bar { }
EOF

cat >${TEST_DIR}${SEP}test19657f.d <<EOF
class Baz {
  import test19657d;
}
EOF

cat >${TEST_DIR}${SEP}test19657g.d <<EOF
import test19657d;
class Seq: Trump {}
EOF

${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} \
       ${TEST_DIR}${SEP}test19657a.d ${TEST_DIR}${SEP}test19657b.d \
       ${TEST_DIR}${SEP}test19657c.d ${TEST_DIR}${SEP}test19657d.d \
       ${TEST_DIR}${SEP}test19657e.d ${TEST_DIR}${SEP}test19657f.d \
       ${TEST_DIR}${SEP}test19657g.d

rm -f ${TEST_DIR}${SEP}${TEST_NAME}${OBJ} ${TEST_DIR}${SEP}${TEST_NAME}*.d
