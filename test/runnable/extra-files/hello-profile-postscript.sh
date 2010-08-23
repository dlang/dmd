#!/bin/bash

diff runnable/extra-files/hello-profile.d.trace.def ${RESULTS_DIR}/runnable/hello-profile.d.trace.def
if [ $? -ne 0 ]; then
    exit 1;
fi

tracelog=${RESULTS_DIR}/runnable/hello-profile.d.trace.log
if [ ! -f ${tracelog} ]; then
    echo "missing file: ${tracelog}"
    exit 1
fi

rm ${RESULTS_DIR}/runnable/hello-profile.d.trace.{def,log}

