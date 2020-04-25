#!/usr/bin/env bash

$DMD -c -o- -main -m${MODEL} ${EXTRA_FILES}/minimal/object.d
