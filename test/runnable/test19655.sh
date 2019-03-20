#! /usr/bin/env bash

TEST_DIR=${OUTPUT_BASE}

mkdir -p ${TEST_DIR}

cat >${TEST_DIR}${SEP}test19655a.d <<EOF
import test19655g;
class Corge
{ }
EOF

cat >${TEST_DIR}${SEP}test19655b.d <<EOF
import test19655c;
import test19655d;
class Garply: Grault
{ }
void main()
{
    (new Garply).func;
}
EOF

cat >${TEST_DIR}${SEP}test19655c.d <<EOF
import test19655f;
import test19655e;
import test19655a: Corge;
class Foo
{
    int[Foo] map;
    void fun0(Corge) { }
}
EOF

cat >${TEST_DIR}${SEP}test19655d.d <<EOF
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

cat >${TEST_DIR}${SEP}test19655e.d <<EOF
import test19655c;
int[Foo] map;
EOF

cat >${TEST_DIR}${SEP}test19655f.d <<EOF
import test19655c;
import test19655g;
EOF

cat >${TEST_DIR}${SEP}test19655g.d <<EOF
import test19655c;
class Bar: Foo
{ }
EOF

${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655a.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655b.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655c.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655d.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655e.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655f.d
${DMD} -m${MODEL} -c -I${TEST_DIR} -od${TEST_DIR} ${TEST_DIR}${SEP}test19655g.d

${DMD} -m${MODEL} -of${TEST_DIR}${SEP}test19655${EXE} ${TEST_DIR}${SEP}test19655a${OBJ} \
       ${TEST_DIR}${SEP}test19655b${OBJ} ${TEST_DIR}${SEP}test19655c${OBJ} \
       ${TEST_DIR}${SEP}test19655d${OBJ} ${TEST_DIR}${SEP}test19655e${OBJ} \
       ${TEST_DIR}${SEP}test19655f${OBJ} ${TEST_DIR}${SEP}test19655g${OBJ}

${TEST_DIR}${SEP}test19655${EXE}

rm -f ${TEST_DIR}${SEP}test19655${EXE} ${TEST_DIR}${SEP}test19655*.d \
   ${TEST_DIR}${SEP}test19655*${OBJ}
