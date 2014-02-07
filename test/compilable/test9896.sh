#!/usr/bin/env bash

dir=${RESULTS_DIR}${DSEP}compilable
src_file=compilable${DSEP}test9896.d
imp_file=compilable${DSEP}imports${DSEP}test9896a.d
object_file=${dir}${DSEP}test9896a${OBJ}

$DMD -m${MODEL} -c ${imp_file} -of${object_file}
$DMD -Icompilable -rb -rx=object -rx=std.* -rx=core.* -rx=etc.* -rx=imports.* -m${MODEL} ${src_file} ${object_file}
