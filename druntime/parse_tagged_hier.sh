#!/usr/bin/env bash

set -euo pipefail

DST_FILE=$1
SRC_COPY_FILE=$2
DST_COPY_FILE=$3
IMPDIR=$4
TAGS=$5
SRC_DIR=$6

if [[ ! -d ${SRC_DIR} ]]; then
    echo "Tags dir '${SRC_DIR}' not found" >&2
    exit 1
fi

if [[ -f ${DST_FILE} ]]; then
    echo "Tagged sources list already generated"
    exit 0
fi

TAGS_LIST=($(echo "$TAGS" | tr "," "\n"))

echo -e "\nTags will be applied: $TAGS"

APPLIED=""

function applyTaggedFiles {
    TAG=$1
    SRC_TAG_DIR=${SRC_DIR}/${TAG}

    if [[ ! -d ${SRC_TAG_DIR} ]]; then
        echo "Warning: tag '${TAG}' doesn't corresponds to any subdirectory inside of '${SRC_DIR}', skip" >&2
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

LINES_TO_COPY=$(grep -v '^$' ${SRC_COPY_FILE} | sort | uniq | wc -l)
COPIED=0

mkdir -p $(dirname ${DST_FILE})
mkdir -p $(dirname ${DST_COPY_FILE})
echo -ne > ${DST_FILE}
echo -ne > ${DST_COPY_FILE}

for i in "${!SRC_FILES_LIST[@]}"
do
    echo ${SRC_FILES_LIST[$i]} >> ${DST_FILE}

    maybe_copy=$(echo ${MAYBE_COPY_LIST[$i]} | tr '/' '\\')

    # Adds copy entry if file mentioned in the list
    grep -F "$maybe_copy" ${SRC_COPY_FILE} > /dev/null && {
        echo ${IMPDIR}'/'${SRC_FILES_LIST[$i]} >> ${DST_COPY_FILE}
        COPIED=$((COPIED+1))
    }
done

if [ $COPIED -ne $LINES_TO_COPY ]; then
    echo "File '$SRC_COPY_FILE' contains $LINES_TO_COPY meaningful line(s), but to '$DST_COPY_FILE' added $COPIED line(s)" >&2

    mv ${DST_FILE} "$DST_FILE.disabled"
    echo "File '$DST_FILE' moved to '$DST_FILE.disabled' to avoid considering that tags parsing process was sucessfully done" >&2
    exit 1
fi

echo "All tags applied"
