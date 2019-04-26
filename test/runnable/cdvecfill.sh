#!/usr/bin/env bash

export LC_ALL=C
src_file=${EXTRA_FILES}/${TEST_NAME}.d
expect_file=${EXTRA_FILES}/${TEST_NAME}.out
expect_file_avx=${EXTRA_FILES}/${TEST_NAME}avx.out
expect_file_avx2=${EXTRA_FILES}/${TEST_NAME}avx2.out
tmp_file=${RESULTS_TEST_DIR}/${TEST_NAME}.out
obj_file=${RESULTS_TEST_DIR}/${TEST_NAME}.o

if [ $OS == "linux" ] && [ $MODEL == "64" ]; then
  $DMD -c -O -m64 ${src_file} -of${obj_file}
  objdump --disassemble --disassembler-options=intel-mnemonic ${obj_file} | tail -n+3 > ${tmp_file}
  diff ${expect_file} ${tmp_file}
  rm ${obj_file} ${tmp_file}

  $DMD -c -O -m64 -mcpu=avx ${src_file} -of${obj_file}
  objdump --disassemble --disassembler-options=intel-mnemonic ${obj_file} | tail -n+3 > ${tmp_file}
  diff ${expect_file_avx} ${tmp_file}
  rm ${obj_file} ${tmp_file}

  $DMD -c -O -m64 -mcpu=avx2 ${src_file} -of${obj_file}
  objdump --disassemble --disassembler-options=intel-mnemonic ${obj_file} | tail -n+3 > ${tmp_file}
  diff ${expect_file_avx2} ${tmp_file}
  rm ${obj_file} ${tmp_file}
fi
