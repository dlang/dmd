#!/usr/bin/env bash

set -euox pipefail

SRC_DIR=$1
DST_DIR=$2

function applyTaggedFiles {
    TAG=$1

    cp -R --backup --suffix=.existed ${SRC_DIR}/${TAG}/* ${DST_DIR}

    FIND_EXISTED=$(find ${DST_DIR} -type f -name "*.existed")

    if [[ "$FIND_EXISTED" != "" ]]; then
        echo "Error: these file(s) already exist before tag '${TAG}' was applied:"
        echo "$FIND_EXISTED"

        exit 1
    fi
}

applyTaggedFiles $3
