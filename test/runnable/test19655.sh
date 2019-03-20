#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}/test19655a.d <<EOF
import test19655g;
class Corge
{ }
EOF

cat >${TEST_DIR}/test19655b.d <<EOF
import test19655c;
import test19655d;
class Garply: Grault
{ }
void main()
{
    (new Garply).func;
}
EOF

cat >${TEST_DIR}/test19655c.d <<EOF
import test19655f;
import test19655e;
import test19655a: Corge;
class Foo
{
    int[Foo] map;
    void fun0(Corge) { }
}
EOF

cat >${TEST_DIR}/test19655d.d <<EOF
import test19655f;
import test19655g;
class Grault: Bar
{
    void func()
    {
      func2;
    }
    void func1()
    {
        assert(false, "func1 was never called");
    }
    void func2() { }
}
EOF

cat >${TEST_DIR}/test19655e.d <<EOF
import test19655c;
int[Foo] map;
EOF

cat >${TEST_DIR}/test19655f.d <<EOF
import test19655c;
import test19655g;
EOF

cat >${TEST_DIR}/test19655g.d <<EOF
import test19655c;
class Bar: Foo
{ }
EOF

${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655a.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655b.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655c.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655d.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655e.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655f.d
${DMD} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}/test19655g.d

${DMD} -of${TEST_DIR}/test19655 ${TEST_DIR}/test19655a.o ${TEST_DIR}/test19655b.o \
       ${TEST_DIR}/test19655c.o ${TEST_DIR}/test19655d.o ${TEST_DIR}/test19655e.o \
       ${TEST_DIR}/test19655f.o ${TEST_DIR}/test19655g.o

${TEST_DIR}/test19655

rm -f ${TEST_DIR}/test19655 ${TEST_DIR}/test19655*.d ${TEST_DIR}/test19655*.o
