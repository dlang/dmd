#!/usr/bin/env bash

grep 'rdeps7016 (.*rdeps7016.d) : private : rdeps7016a' ${RESULTS_DIR}/compilable/rdeps7016.deps
grep 'rdeps7016a (.*rdeps7016a.d) : private : rdeps7016b' ${RESULTS_DIR}/compilable/rdeps7016.deps
grep 'rdeps7016b (.*rdeps7016b.d) : private : rdeps7016' ${RESULTS_DIR}/compilable/rdeps7016.deps
rm -f ${RESULTS_DIR}/compilable/rdeps7016.deps
