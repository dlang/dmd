#!/usr/bin/env bash
grep  'depsOutput9948 (.*depsOutput9948.d) : private : std.string'  ${RESULTS_DIR}/compilable/depsOutput9948.deps
! grep  'depsOutput9948a (.*depsOutput9948a.d) : private : std.string'  ${RESULTS_DIR}/compilable/depsOutput9948.deps
! grep  '__entrypoint'  ${RESULTS_DIR}/compilable/depsOutput9948.deps
rm -f ${RESULTS_DIR}/compilable/depsOutput9948.deps
