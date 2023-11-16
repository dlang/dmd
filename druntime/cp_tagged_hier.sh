#!/usr/bin/env bash

set -euo pipefail

SRC_DIR=$1
DST_DIR=$2
TAGS=$3

DONE_FLAG_FILE=${DST_DIR}/GENERATED

if [[ -f ${DONE_FLAG_FILE} ]]; then
    echo "Tagged sources directory already generated"

    exit 0
else
    # Prepare to generate or re-generate
    mkdir -p ${DST_DIR}
    rm -rf ${DST_DIR}/*
fi

TAGS_LIST=($(echo "$TAGS,default" | tr "," "\n"))

echo -e "\nTags will be applied (except default): $TAGS"

APPLIED=""

function applyTaggedFiles {
    TAG=$1

    cp -R --backup --suffix=.existed ${SRC_DIR}/${TAG}/* ${DST_DIR}

    FIND_EXISTED=$(find ${DST_DIR} -type f -name "*.existed")

    if [[ "$FIND_EXISTED" != "" ]]; then
        echo "Error: these file(s) already exist before tag '${TAG}' was applied:"
        echo "$FIND_EXISTED"

        echo "Currently applied tags list:$APPLIED"
        echo "Not applied tag: ${TAG}"
        exit 1
    fi

    APPLIED+=" $TAG"

    echo "Currently applied tags:$APPLIED"
}

for tag in "${TAGS_LIST[@]}"
do
    applyTaggedFiles ${tag}
done

echo "All tags applied"

touch ${DONE_FLAG_FILE}
