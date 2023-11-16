#!/usr/bin/env bash

set -euox pipefail

SRC_DIR=$1
DST_FILE=$2
TAGS=$3

if [[ -f ${DST_FILE} ]]; then
    echo "Tagged sources list already generated"

    exit 0
fi

TAGS_LIST=($(echo "$TAGS,default" | tr "," "\n"))

echo -e "\nTags will be applied (except default): $TAGS"

APPLIED=""

function applyTaggedFiles {
    TAG=$1
    SRC_TAG_DIR=${SRC_DIR}/${TAG}

    if [[ ! -d ${SRC_TAG_DIR} ]]; then
        echo "Tag '${TAG}' doesn't corresponds to any subdirectory inside of '${SRC_DIR}', skip"
        return 0
    fi

    SRC_FILES_LIST+=($(find ${SRC_TAG_DIR} -type f ))

    APPLIED+=" $TAG"

    echo "Currently applied tags:$APPLIED"
}

for tag in "${TAGS_LIST[@]}"
do
    applyTaggedFiles ${tag}
done

echo "TAGGED_SRCS_LIST=\\" > ${DST_FILE}
for l in "${SRC_FILES_LIST[@]}"
do
    echo "$l \\" | tr '/' '\\' >> ${DST_FILE}
done

echo "All tags applied"
