#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}${SEP}test19656.d <<EOF
import test19656a;
import test19656c: Thud;
class Foo
{
    Foo[Foo] _map;
    void func (Thud ) { }
    void thunk () { }
}
EOF

cat >${TEST_DIR}${SEP}test19656b.d <<EOF
import test19656;
class Bar { }
class Qux(T): Foo
{
    override void thunk() { }
}
class Fred
{
    Qux!Bar _q;
}
EOF

cat >${TEST_DIR}${SEP}test19656c.d <<EOF
import test19656b;
class Thud { }
EOF

cat >${TEST_DIR}${SEP}test19656a.d <<EOF
import test19656;
class Corge: Foo { }
EOF

${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}${TEST_NAME}.d
rm -f ${TEST_DIR}${SEP}${TEST_NAME}${OBJ} ${TEST_DIR}${SEP}${TEST_NAME}*.d
