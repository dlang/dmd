#!/usr/bin/env bash

set -euox pipefail

SRC_DIR=$1
DST_FILE=$2 #TODO: rename
SRC_COPY_FILE=$3
DST_COPY_FILE=$4
TAGS=$5

if [[ ! -d ${SRC_DIR} ]]; then
    echo "Tags dir '${SRC_DIR}' not found"
    return 1
fi

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

    pushd ${SRC_TAG_DIR}
    MAYBE_COPY_LIST+=($(find * -type f ))
    popd

    APPLIED+=" $TAG"

    echo "Currently applied tags:$APPLIED"
}

for tag in "${TAGS_LIST[@]}"
do
    applyTaggedFiles ${tag}
done

echo "TAGGED_SRCS_LIST=\\" > ${DST_FILE}
echo "TAGGED_COPY_LIST=\\" > ${DST_COPY_FILE}

for i in "${!SRC_FILES_LIST[@]}"
do
    fl=$(echo "${SRC_FILES_LIST[$i]} \\" | tr '/' '\\')
    echo ${fl} >> ${DST_FILE}

    maybe_copy=$(echo "${MAYBE_COPY_LIST[$i]}" | tr '/' '\\')

    #FIXME: weak code:
    grep -F "$maybe_copy" < ${SRC_COPY_FILE} && echo ${fl} >> ${DST_COPY_FILE}
done

echo "All tags applied"
