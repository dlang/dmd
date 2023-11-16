#!/usr/bin/env bash

set -euox pipefail

function linkFile {
    SRC=${1}
    DST=${2}
    TAG=${3}

    if [[ -a ${DST} ]]; then
        echo "Error: attempt to replace '$DST_FILE' by file from '$TAG'"
        exit 1
    fi

    DST_PATH=$(dirname ${DST})
    mkdir -p ${DST_PATH}

    #FIXME
    #~ if [[ "$OSTYPE" == "msys" ]]; then
        cp ${SRC} ${DST}
    #~ else
        #~ ln -s ${SRC} ${DST}
    #~ fi
}

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
    SRC_TAG_DIR=${SRC_DIR}/${TAG}

    if [[ ! -d ${SRC_TAG_DIR} ]]; then
        echo "Tag '${TAG}' doesn't corresponds to subdirectory inside of '${SRC_DIR}', skip"
        return 0
    fi

    pushd ${SRC_TAG_DIR}
    FILES=($(find . -type f))
    popd

    for curr_file in "${FILES[@]}"
    do
        linkFile ${SRC_TAG_DIR}/${curr_file} ${DST_DIR}/${curr_file} ${SRC_TAG_DIR}
    done

    APPLIED+=" $TAG"

    echo "Currently applied tags:$APPLIED"
}

for tag in "${TAGS_LIST[@]}"
do
    applyTaggedFiles ${tag}
done

echo "All tags applied"

touch ${DONE_FLAG_FILE}
