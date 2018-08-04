#!/usr/bin/env bash
set -e
GDEPFILE=${RESULTS_DIR}/compilable/makedeps.dep
GDEPFILE_a=${RESULTS_DIR}/compilable/makedeps_a.dep
grep  'makedeps_[0-9]*.o:' ${GDEPFILE} || # some platforms use .obj instead of .o for object files.
grep  'makedeps_[0-9]*.obj:' ${GDEPFILE}
# The test runner will generate a single object file from both source files, hence the same target name
grep  'makedeps_[0-9]*.o:'  ${GDEPFILE_a} ||
grep  'makedeps_[0-9]*.obj:'  ${GDEPFILE_a}
grep  'makedeps.d'  ${GDEPFILE}
grep  'makedeps.sh'  ${GDEPFILE}
grep  'makedeps_a.d'  ${GDEPFILE}
grep  'object.d'  ${GDEPFILE}
! grep  '__entrypoint'  ${GDEPFILE}
rm -f ${GDEPFILE} ${GDEPFILE_a}
