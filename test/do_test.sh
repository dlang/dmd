#!/usr/bin/env bash

# enable debugging
# set -x

# cmd line args
input_dir=$1    # ex: runnable
test_name=$2    # ex: pi
test_extension=$3 # ex: d html or sh

# env vars
# ARGS        == default set of dmd command line args to test combinatorially
# DMD         == compiler path and filename
# RESULTS_DIR == directory for temporary files and output
# MODEL       == 32 || 64

# tedious env vars
# DSEP        == \\ or / depending on windows or not
# SEP         == \ or / depending on windows or not
# OBJ         == .obj or .o
# EXE         == .exe or <null>

# enable support for expressions like *( ) in substitutions
shopt -s extglob

# NOTE: $? tests below test for greater than 125:
#   126 -- command found but isn't executable
#   127 -- command not found
#   128+N -- N is the signal that caused the process to exit
#            for example, segv == 11, so $? will be 139
#                         abort == 6, so $? will be 134

input_file=${input_dir}/${test_name}.${test_extension}
output_dir=${RESULTS_DIR}${SEP}${input_dir}
output_file=${RESULTS_DIR}/${input_dir}/${test_name}.${test_extension}.out
test_app_dmd=${output_dir}${SEP}${test_name}
test_app_exe=${RESULTS_DIR}/${input_dir}/${test_name}

rm -f ${output_file}

r_args=`grep REQUIRED_ARGS ${input_file} | tr -d \\\\r\\\\n`
if [ ! -z "${r_args}" ]; then
    r_args="${r_args/*REQUIRED_ARGS:*( )/}"
    if [ ! -z "${r_args}" ]; then
        extra_space=" "
    fi
fi

p_args=`grep PERMUTE_ARGS ${input_file} | tr -d \\\\r\\\\n`
if [ -z "${p_args}" ]; then
    if [ "${input_dir}" != "fail_compilation" ]; then
        p_args="${ARGS}"
    fi
else
    p_args="${p_args/*PERMUTE_ARGS:*( )/}"
    if [ "${OS}" == "win32" ]; then
        p_args="${p_args/-fPIC/}"
    fi
fi

if [ "${MODEL}" == "64" ]; then
    p_args="${p_args/-O/}"
    r_args="${r_args/-O/}"
fi

e_args=`grep EXECUTE_ARGS  ${input_file} | tr -d \\\\r\\\\n`
if [ ! -z "$e_args" ]; then
    e_args="${e_args/*EXECUTE_ARGS:*( )/}"
fi

extra_sources=`grep EXTRA_SOURCES ${input_file} | tr -d \\\\r\\\\n`
if [ ! -z "${extra_sources}" ]; then
    # remove the field name, leaving just the list of files
    extra_sources=(${extra_sources/*EXTRA_SOURCES:*( )/})
    # prepend the test dir (ie, runnable) to each extra file
    #extra_sources=(${extra_sources[*]/imports\//${input_dir}\/imports\/})
    prefixed_extra_sources=()
    for tmp in ${extra_sources[*]}; do prefixed_extra_sources=(${prefixed_extra_sources[*]} "${input_dir}/${tmp}"); done
    all_sources=(${input_file} ${prefixed_extra_sources[*]})
else
    all_sources=(${input_file})
fi
# replace / with the correct separator
all_sources=(${all_sources[*]//\//${SEP}})

grep -q COMPILE_SEPARATELY ${input_file}
separate=$?

post_script=`grep POST_SCRIPT ${input_file} | tr -d \\\\r\\\\n`
if [ ! -z "${post_script}" ]; then
    post_script="${post_script/*POST_SCRIPT:*( )/}"
fi

if [ "${input_dir}" != "runnable" ]; then
    extra_compile_args="-c"
fi

if [ "${input_dir}" == "fail_compilation" ]; then
    expect_compile_rc=1
else
    expect_compile_rc=0
fi


printf " ... %-25s %s%s(%s)\n" "${input_file}" "${r_args}" "${extra_space}" "${p_args}"

${RESULTS_DIR}/combinations ${p_args} | while read x; do

    if [ ${separate} -ne 0 ]; then
        echo ${DMD} -m${MODEL} -I${input_dir} ${r_args} $x -od${output_dir} -of${test_app_dmd} ${extra_compile_args} ${all_sources[*]} >> ${output_file}
             ${DMD} -m${MODEL} -I${input_dir} ${r_args} $x -od${output_dir} -of${test_app_dmd} ${extra_compile_args} ${all_sources[*]} >> ${output_file} 2>&1
        if [ $? -ne ${expect_compile_rc} -o $? -gt 125 ]; then
            cat ${output_file}
            rm -f ${output_file}
            exit 1
        fi
    else
        for file in ${all_sources[*]}; do
            echo ${DMD} -m${MODEL} -I${input_dir} ${r_args} $x -od${output_dir} -c $file >> ${output_file}
                 ${DMD} -m${MODEL} -I${input_dir} ${r_args} $x -od${output_dir} -c $file >> ${output_file} 2>&1
            if [ $? -ne ${expect_compile_rc} -o $? -gt 125 ]; then
                cat ${output_file}
                rm -f ${output_file}
                exit 1
            fi
        done

        all_os=(${all_sources[*]/%.d/${OBJ}})
        all_os=(${all_os[*]/${DSEP}imports${DSEP}/${SEP}})
        all_os=(${all_os[*]/#/${RESULTS_DIR}${SEP}})

        if [ "${input_dir}" = "runnable" ]; then
            echo ${DMD} -m${MODEL} -od${output_dir} -of${test_app_dmd} ${all_os[*]} >> ${output_file}
                 ${DMD} -m${MODEL} -od${output_dir} -of${test_app_dmd} ${all_os[*]} >> ${output_file} 2>&1
            if [ $? -ne ${expect_compile_rc} -o $? -gt 125 ]; then
                cat ${output_file}
                rm -f ${output_file}
                exit 1
            fi
        fi
    fi

    if [ "${input_dir}" = "runnable" ]; then
        echo ${test_app_exe} ${e_args} >> ${output_file}
             ${test_app_exe} ${e_args} >> ${output_file} 2>&1
        if [ $? -ne 0 ]; then
            cat ${output_file}
            rm -f ${output_file}
            exit 1
        fi
    fi

    if [ ! -z ${post_script} ]; then
        echo "Executing post-test script: ${post_script}" >> ${output_file}
        ${post_script} >> ${output_file} 2>&1
        if [ $? -ne 0 ]; then
            cat ${output_file}
            rm -f ${output_file}
            exit 1
        fi
    fi

    rm -f ${test_app_exe} ${test_app_exe}${OBJ} ${all_os[*]}

    echo >> ${output_file}
done


