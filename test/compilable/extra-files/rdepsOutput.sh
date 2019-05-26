#!/usr/bin/env bash

grep 'rdeps7016 (.*rdeps7016.d) : private : rdeps7016a' ${OUTPUT_BASE}.deps
grep 'rdeps7016a (.*rdeps7016a.d) : private : rdeps7016b' ${OUTPUT_BASE}.deps
grep 'rdeps7016b (.*rdeps7016b.d) : private : rdeps7016' ${OUTPUT_BASE}.deps
rm -f ${OUTPUT_BASE}.deps
