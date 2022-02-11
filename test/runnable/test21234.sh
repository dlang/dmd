#!/usr/bin/env bash

set -e

rm_retry -r ${OUTPUT_BASE}
mkdir -p ${OUTPUT_BASE}/import

cat > ${OUTPUT_BASE}/src.d << EOF
void main()
{
    pragma(msg, import("file"));
}
EOF

cat > ${OUTPUT_BASE}/file << EOF
Hello!
EOF

ln -s ../file ${OUTPUT_BASE}/import/file

# ln can be disfunction when run via WSL
if [[ -f ../file ]]
then
    $DMD -o- -od=${OUTPUT_BASE} -J=${OUTPUT_BASE}/import ${OUTPUT_BASE}/src.d
fi

rm_retry -r ${OUTPUT_BASE}
