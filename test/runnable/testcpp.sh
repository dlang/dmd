#!/usr/bin/env bash

src=runnable${SEP}extra-files
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/testcpp.sh.out

if [ $OS == "win32" -o  $OS == "win64" ]; then
	dmc -c ${src}${SEP}cppb
	$DMD -m${MODEL} -I${src} -of${dir}${SEP}cppa${EXE} ${src}${SEP}cppa.d -of${dir}${SEP}cppb${OBJ} || exit 1
	cppa
else
	$DMD -m${MODEL} -c -I${src} -of${dir}${SEP}cppa${OBJ} ${src}${SEP}cppa.d
	g++ -m${MODEL} -c  ${src}${SEP}cppb.cpp
	g++ -m${MODEL} ${dir}${SEP}cppa.o ${dir}${SEP}cppb.o -o ${dir}${SEP}cppa -m32 -l:libphobos2.a -lpthread -lm -lrt
	./cppa
fi


rm ${dir}/{cppa${OBJ},cppb${OBJ},cppa${EXE}}

echo Success >${output_file}

dmc -c cppb
dmd cppa cppb.obj
cppa


