#!/usr/bin/env bash
set -e
grep  "make\\ deps:"  ${RESULTS_DIR}/compilable/makedeps2.dep
grep  'makedeps2.d'  ${RESULTS_DIR}/compilable/makedeps2.dep
grep  'makedeps.sh'  ${RESULTS_DIR}/compilable/makedeps2.dep
grep  'makedeps_a.d'  ${RESULTS_DIR}/compilable/makedeps2.dep
grep  'object.d'  ${RESULTS_DIR}/compilable/makedeps2.dep
! grep  '__entrypoint'  ${RESULTS_DIR}/compilable/makedeps2.dep
rm -f ${RESULTS_DIR}/compilable/makedeps2.dep
