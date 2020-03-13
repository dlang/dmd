#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}${SEP}test19746.d <<EOF
import test19746c;
import test19746b: Frop;
template Base(T)
{
    static if (is(T == super)) alias Base = Object;
}
class Foo
{
    class Nested: Base!Foo { }
    void func(Frop) { }
    void thunk() { }
}
EOF

cat >${TEST_DIR}${SEP}test19746a.d <<EOF
import test19746;
class Bar: Foo { }
EOF

cat >${TEST_DIR}${SEP}test19746b.d <<EOF
import test19746d;
class Frop { }
EOF

cat >${TEST_DIR}${SEP}test19746c.d <<EOF
import test19746a;
class Qux: Bar { } 
EOF

cat >${TEST_DIR}${SEP}test19746d.d <<EOF
import test19746;
class Baz(T): Foo { }
class Dap(T): Baz!T
{
    override void thunk() {}
}
class Zoo
{
    Dap!int _dap;
}
EOF

${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}${TEST_NAME}.d
rm -f ${TEST_DIR}${SEP}${TEST_NAME}${OBJ} ${TEST_DIR}${SEP}${TEST_NAME}*.d
