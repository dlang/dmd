#!/usr/bin/env bash
grep  'depsOutput9948 (.*depsOutput9948.d) : private : std.string'  ${OUTPUT_BASE}.deps
! grep  'depsOutput9948a (.*depsOutput9948a.d) : private : std.string'  ${OUTPUT_BASE}.deps
! grep  '__entrypoint'  ${OUTPUT_BASE}.deps
rm -f ${OUTPUT_BASE}.deps
