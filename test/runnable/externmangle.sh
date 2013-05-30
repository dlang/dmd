#!/usr/bin/env bash

dmddir=${RESULTS_DIR}${SEP}runnable
dir=${RESULTS_DIR}/runnable
dmd_output_file=${dmddir}${SEP}externmangle.sh.out
output_file=${dir}/externmangle.sh.out

output_file_cppo_name=externmangle${OBJ}
output_file_cppo=${dmddir}${SEP}${output_file_cppo_name}
testfilesdir=runnable${SEP}extra-files

test_file_cpp=${testfilesdir}${SEP}externmangle.cpp
test_file_d=${testfilesdir}${SEP}externmangle.d


rm -f ${output_file}${EXE}

die()
{
    echo "$@"
    rm -f ${output_file}${EXE}
    rm -f ${output_file_cppo}
    exit 1
}

#determination version of the compiler:

if $DMD --help | grep -q "DMD"; then 
    compiler=dmd
    outopt="-of"
    stdcpplib="-L-lstdc++"
fi

if $DMD --help | grep -q "ldc"; then 
    compiler=ldc
    outopt="-of"
    stdcpplib="-L-lstdc++"
fi

if $DMD --help | grep -q "gdc"; then 
    compiler=gdc
    outopt="-o"
    stdcpplib="-Xlinker -lstdc++"
fi

if [ "$compiler" == '' ]; then 
    die "Unknown compiler '$DMD'"
fi


if [ "$compiler" == 'dmd' ]; then 
    case ${OS} in
        "win32") dmc -c $test_file_cpp -o$output_file_cppo || exit 1 ; stdcpplib="" ;;
        "win64") exit 0 ;; #don't know, what c++ compiler need for win64 + dmd
        *) g++ -m${MODEL} -c $test_file_cpp -o $output_file_cppo || exit 1;;
    esac
else
    g++ -m${MODEL} -c $test_file_cpp -o$output_file_cppo || exit 1
fi

$DMD -m${MODEL} $stdcpplib $outopt${dmd_output_file}${EXE} $test_file_d $output_file_cppo || exit 1
./$output_file || exit 1
