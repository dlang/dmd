#!/bin/bash

grep -v "\"file\" : " ${RESULTS_DIR}/compilable/json.out > ${RESULTS_DIR}/compilable/json.out.2
diff compilable/extra-files/json.out ${RESULTS_DIR}/compilable/json.out.2
if [ $? -ne 0 ]; then
    exit 1;
fi

rm ${RESULTS_DIR}/compilable/json.out{,.2}

