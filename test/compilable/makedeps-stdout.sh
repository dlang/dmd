#!/usr/bin/env bash

mkdir -p $OUTPUT_BASE

cat >$OUTPUT_BASE/makedeps.d <<EOF
module makedeps;

// Test import statement
import makedeps_a;

// Test import expression
enum text = import("makedeps-import.txt");
static assert(text == "Imported text");

void main()
{
    a_func();
}
EOF

DEPFILE=${OUTPUT_BASE}/depfile.dep

${DMD} -c -of=${OUTPUT_BASE}/makedeps.o -makedeps \
    -Jcompilable/extra-files -Icompilable/extra-files \
    $OUTPUT_BASE/makedeps.d > ${DEPFILE}

set -e
grep  'makedeps*.o:' ${DEPFILE} || # some platforms use .obj instead of .o for object files.
grep  'makedeps*.obj:' ${DEPFILE}
# The test runner will generate a single object file from both source files, hence the same target name
grep  'makedeps.d' ${DEPFILE}
grep  'makedeps-import.txt' ${DEPFILE}
grep  'makedeps_a.d' ${DEPFILE}
grep  'object.d' ${DEPFILE}
! grep  '__entrypoint' ${DEPFILE}
rm -f ${DEPFILE}