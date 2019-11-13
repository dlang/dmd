#!/usr/bin/env bash

# tests various --opt=<value> switches:
#
# -Dd=<directory>
# -Df=<filename>
# -Hd=<directory>
# -Hf=<filename>
# -I=<directory>
# -J=<directory>
# -L=<linkerflag>
# -od=<dirname>
# -of=<objname>
# -Xf=<filename>

src_file=${OUTPUT_BASE}/src.d

clean()
{
    rm -rf ${OUTPUT_BASE}
}

prepare()
{
    clean;
    mkdir -p ${OUTPUT_BASE}
    echo "module mymod;" > ${OUTPUT_BASE}/mymod.d
    echo "module src; import mymod;" > ${src_file}
}

die()
{
    echo "test_switches.sh error: Output file $1 not found"
    exit 1
}

checkFile()
{
    if [ ! -f $1 ]; then die $1; fi
}

checkFiles()
{
    checkFile ${OUTPUT_BASE}/json.json
    checkFile ${OUTPUT_BASE}/mymod.d
    checkFile ${OUTPUT_BASE}/src.d
    checkFile ${OUTPUT_BASE}/src.di
    checkFile ${OUTPUT_BASE}/src.html
}

# @BUG@: -Df doesn't take -Dd into account when it's set
# @BUG@: -Hf doesn't take -Hd into account when it's set
# Workaround: Call DMD twice, first with -Df / -Hf, then with -Dh and -Hd
# Note: -L linker flag not explicitly checked (using -c to compile only)
# as there's no common linker switch which all linkers support

prepare;
$DMD -o- -od=${OUTPUT_BASE} -D -Df=${OUTPUT_BASE}/src.html -Hf=${OUTPUT_BASE}/src.di -I=${OUTPUT_BASE} -L=-v -Xf=${OUTPUT_BASE}/json.json ${src_file}
checkFiles;

prepare;
$DMD -o- -od=${OUTPUT_BASE} -D -Dd=${OUTPUT_BASE} -Hd=${OUTPUT_BASE} -I=${OUTPUT_BASE} -L=-v -Xf=${OUTPUT_BASE}/json.json ${src_file}
checkFiles;

clean;
