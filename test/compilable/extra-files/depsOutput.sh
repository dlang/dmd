#!/usr/bin/env bash
grep  'depsOutput9948 (.*depsOutput9948.d) : private : std.string'  ${RESULTS_DIR}/compilable/depsOutput9948.deps || exit 1
grep  'depsOutput9948a (.*depsOutput9948a.d) : private : std.string'  ${RESULTS_DIR}/compilable/depsOutput9948.deps && exit 1
grep  '__entrypoint'  ${RESULTS_DIR}/compilable/depsOutput9948.deps && exit 1
rm -f ${RESULTS_DIR}/compilable/depsOutput9948.deps
exit 0
