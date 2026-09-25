#!/usr/bin/env bash

$DMD -o- -Hf"${OUTPUT_BASE}.di" "${EXTRA_FILES}/enum_union_header_hardening.d"
$DMD -c -of"${OUTPUT_BASE}.${OBJ}" -I"$(dirname "${OUTPUT_BASE}")" \
    "${EXTRA_FILES}/enum_union_header_hardening_consumer.d"