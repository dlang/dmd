#!/usr/bin/env bash

OLDHOME=$HOME
export HOME=`pwd`

goerror(){
    export HOME=$OLDHOME
    echo "="
    echo "= *** Error ***"
    echo "="
    exit 1
}

make clean unittest -fdmd-posix.mak || goerror
make clean -fdmd-posix.mak          || goerror

export HOME=$OLDHOME
