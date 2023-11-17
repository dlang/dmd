#!/usr/bin/env bash

set -euo pipefail

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
    else
        SRC_FILES_LIST+=($(find ${SRC_TAG_DIR} -type f ))

        pushd ${SRC_TAG_DIR} > /dev/null
        MAYBE_COPY_LIST+=($(find * -type f ))
        popd > /dev/null
    fi

    APPLIED+=" $TAG"

    echo "Currently applied tags:$APPLIED"
}

for tag in "${TAGS_LIST[@]}"
do
    applyTaggedFiles ${tag}
done

let LINES_TO_COPY=$(grep -v '^$' ${SRC_COPY_FILE} | wc -l)
COPIED=0

echo "TAGGED_SRCS_LIST=\\" > ${DST_FILE}
echo "TAGGED_COPY_LIST=\\" > ${DST_COPY_FILE}

for i in "${!SRC_FILES_LIST[@]}"
do
    fl=$(echo "${SRC_FILES_LIST[$i]} \\" | tr '/' '\\')
    echo ${fl} >> ${DST_FILE}

    maybe_copy=$(echo "${MAYBE_COPY_LIST[$i]}" | tr '/' '\\')

    # Adds copy entry if file mentioned in the list
    grep -F "$maybe_copy" ${SRC_COPY_FILE} && {
        echo ${fl} >> ${DST_COPY_FILE}
        let "COPIED+=1"
    }
done

if [ $COPIED -ne $LINES_TO_COPY ]; then
    echo "File '$SRC_COPY_FILE' contains $LINES_TO_COPY meaningful line(s), but to '$DST_COPY_FILE' added $COPIED lines"

    mv ${DST_FILE} "$DST_FILE.disabled"
    echo "File '$DST_FILE' to '$DST_FILE.disabled' to avoid considering that tags parsing process was sucessfully done"
    exit 1
fi

echo "All tags applied"
