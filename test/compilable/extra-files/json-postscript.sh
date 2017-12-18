#!/usr/bin/env bash

grep -v "\"file\" : " ${RESULTS_DIR}/compilable/json.out | grep -v "\"offset\" : " | grep -v "\"deco\" : " > ${RESULTS_DIR}/compilable/json.out.2
grep -v "\"file\" : " compilable/extra-files/json.out | grep -v "\"offset\" : " | grep -v "\"deco\" : " > ${RESULTS_DIR}/compilable/json.out.3

diff --strip-trailing-cr ${RESULTS_DIR}/compilable/json.out.2 ${RESULTS_DIR}/compilable/json.out.3
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/json.out{.2,.3}
