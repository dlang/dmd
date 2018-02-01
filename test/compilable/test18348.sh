#!/usr/bin/env bash

set -eu pipefail

dir=${RESULTS_DIR}${SEP}compilable
output_file=${dir}/test18348.sh.out

faketty () { script -qfc "$(printf "%q " "$@")" /dev/null ; }
export TERM="faketerm"

check()
{
    # the first sed removes remove carriage returns
    out=$(echo "$1" |
        faketty "$DMD" -c -o- -color=on - | tail -n+2 | \
        sed 's/\x0d//g' | \
        sed 's/\x1b\[m/|RESET|/g' |
        sed 's/\x1b\[1m/|BOLD|/g' | \
        sed 's/\x1b\[0;\([0-9]*\)m/|+++\1|/g' | \
        sed 's/\x1b\[1;\([0-9]*\)m/|BOLD++++\1|/g' | \
        sed 's/+++30|/BLACK|/g' | \
        sed 's/+++31|/RED|/g' | \
        sed 's/+++32|/GREEN|/g' | \
        sed 's/+++33|/YELLOW|/g' | \
        sed 's/+++34|/BLUE|/g' | \
        sed 's/+++35|/PURPLE|/g' | \
        sed 's/+++36|/CYAN|/g' | \
        sed 's/+++37|/WHITE|/g')
    expected="$2"
    if [ "$out" != "$expected" ] ; then
        echo "Expected: $expected"
        echo "Actual:   $out"
        exit 1
    fi
}

if ! [ $OS == "win32" -o  $OS == "win64" ]; then
    check "test" \
        "|BOLD|__stdin.d(2): |BOLD+RED|Error: |RESET|no identifier for declarator |CYAN||BOLD+WHITE|test|CYAN||RESET|"
    check "void foo(){'a'.b;}" \
        "|BOLD|__stdin.d(1): |BOLD+RED|Error: |RESET|no property |CYAN||BOLD+WHITE|b|CYAN||RESET| for type |CYAN||BOLD+WHITE|char|CYAN||RESET|"
fi

echo Success >${output_file}
