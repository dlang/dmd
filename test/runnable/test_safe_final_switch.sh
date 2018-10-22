#!/usr/bin/env bash

# tests various @safe behavior for final switches in
# -release and non-release builds

src_file=runnable/extra-files/test11051.d

die()
{
    echo "test_safe_final_switch.sh error: test #$1 failed"
    exit 1
}

$DMD -run ${src_file} 2> /dev/null

die()
{
    exit 1
}

# returns 1 (failure)
$DMD -run ${src_file} 2> /dev/null && die 1

# returns 0 (success)
$DMD -release -run ${src_file} 2> /dev/null || die 2

# returns 1 (failure)
$DMD -version=Safe -run ${src_file} 2> /dev/null && die 3

# returns 1 (failure)
$DMD -release -version=Safe -run ${src_file} 2> /dev/null && die 4

exit 0
