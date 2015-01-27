#!/usr/bin/env bash

grep -v "D import file generated from" ${RESULTS_DIR}/compilable/$1.di > ${RESULTS_DIR}/compilable/$1.di.2
diff --strip-trailing-cr compilable/extra-files/$1.di ${RESULTS_DIR}/compilable/$1.di.2
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/$1.di{,.2}

