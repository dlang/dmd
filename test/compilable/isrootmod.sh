#!/usr/bin/env bash

$DMD -m$MODEL -o- -I=$EXTRA_FILES $EXTRA_FILES/rootmodmain.d 2>&1 | grep -q "isRootModule 0"
$DMD -m$MODEL -o- -I=$EXTRA_FILES $EXTRA_FILES/rootmodmain.d $EXTRA_FILES/rootmodimport 2>&1 | grep -q "isRootModule 1"
$DMD -m$MODEL -o- -I=$EXTRA_FILES $EXTRA_FILES/rootmodmain.d -i 2>&1 | grep -q "isRootModule 1"
