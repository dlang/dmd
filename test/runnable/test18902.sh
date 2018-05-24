#!/usr/bin/env bash

$DMD -m${MODEL} -lib 18902.a || test $? = 1
