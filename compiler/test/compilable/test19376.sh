#!/usr/bin/env bash


$DMD -c -of${OUTPUT_BASE} ${EXTRA_FILES}/test19376.di
! ls ${OUTPUT_BASE}/test19376.${OBJ}
