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

out_dir=${RESULTS_DIR}/runnable/test_switches
src_file=${out_dir}/src.d

clean()
{
    rm -rf ${out_dir} || true
}

prepare()
{
    clean;
    mkdir ${out_dir}
    echo "module mymod;" > ${out_dir}/mymod.d
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
    checkFile ${out_dir}/json.json
    checkFile ${out_dir}/mymod.d
    checkFile ${out_dir}/src.d
    checkFile ${out_dir}/src.di
    checkFile ${out_dir}/src.html
}

# @BUG@: -Df doesn't take -Dd into account when it's set
# @BUG@: -Hf doesn't take -Hd into account when it's set
# Workaround: Call DMD twice, first with -Df / -Hf, then with -Dh and -Hd
# Note: -L linker flag not explicitly checked (using -c to compile only)
# as there's no common linker switch which all linkers support

prepare;
$DMD -c -of=mymod.o -od=${out_dir} -D -Df=${out_dir}/src.html -Hf=${out_dir}/src.di -I=${out_dir} -L=-v -Xf=${out_dir}/json.json ${src_file}
checkFiles;

prepare;
$DMD -c -of=mymod.o -od=${out_dir} -D -Dd=${out_dir} -Hd=${out_dir} -I=${out_dir} -L=-v -Xf=${out_dir}/json.json ${src_file}
checkFiles;

clean;
