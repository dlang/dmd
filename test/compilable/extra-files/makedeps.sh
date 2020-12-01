#!/usr/bin/env bash
set -e
DEPFILE=${RESULTS_DIR}/compilable/makedeps.dep
grep  'makedeps_[0-9]*.o:' ${DEPFILE} || # some platforms use .obj instead of .o for object files.
grep  'makedeps_[0-9]*.obj:' ${DEPFILE}
# The test runner will generate a single object file from both source files, hence the same target name
grep  'makedeps.d' ${DEPFILE}
grep  'makedeps_a.d' ${DEPFILE}
grep  'makedeps-import.txt' ${DEPFILE}
grep  'object.d' ${DEPFILE}
! grep  '__entrypoint' ${DEPFILE}
rm -f ${DEPFILE}
