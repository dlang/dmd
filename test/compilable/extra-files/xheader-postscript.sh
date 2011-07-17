#!/usr/bin/env bash

grep -v "D import file generated from" ${RESULTS_DIR}/compilable/xheader.di > ${RESULTS_DIR}/compilable/xheader.di.2
diff --strip-trailing-cr compilable/extra-files/xheader.di ${RESULTS_DIR}/compilable/xheader.di.2
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/xheader.di{,.2}

