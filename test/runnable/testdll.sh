#!/usr/bin/env bash

if [ $OS == "win32" -o  $OS == "win64" ]; then
	DLLEXT=.dll
	LIBEXT=.lib
else
	exit 0
fi

src=runnable${SEP}extra-files
dllsrc=${src}${SEP}testdll
dir=${RESULTS_DIR}${SEP}runnable
output_file=${dir}/testdll.sh.out

exename=${dir}${SEP}testdll${EXE}
dllname=${dir}${SEP}mydll${DLLEXT}
libname=${dir}${SEP}mydll${LIBEXT}

$DMD -m${MODEL} -of${dllname} -L"/IMPLIB:mydll${LIBEXT}" ${dllsrc}${SEP}{mydll.d,dllmain.d,mydll.def}

mv mydll${LIBEXT} ${libname}

$DMD -m${MODEL} -I${src} -of${exename} ${src}${SEP}testdll.d ${libname}

rm ${dir}/{testdll,mydll}${OBJ}
rm ${exename} ${dllname} ${libname}
