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

make clean -fdmd-posix.mak           || goerror
make lib doc install -fdmd-posix.mak || goerror
make clean -fdmd-posix.mak           || goerror
chmod 644 ../import/*.di             || goerror

export HOME=$OLDHOME
