#!/usr/bin/env bash

echo "export extern(C) int lib_get_int() { return 42; }" >> fake.d
dmd -betterC -lib fake.d
