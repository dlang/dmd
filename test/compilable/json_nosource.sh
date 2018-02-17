#!/usr/bin/env bash
$DMD -Xi=compilerInfo -Xf=${RESULTS_DIR}/compilable/json_nosource.out
./compilable/extra-files/json-postscript.sh json_nosource
