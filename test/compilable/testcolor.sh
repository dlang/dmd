#!/usr/bin/env bash
set -eo pipefail

# We never use ANSI codes on Windows, so, we can't test them.
if [[ $OS = *"win"* ]]; then exit 0; fi

compare()
{
    local actual="$1"
    local expected="$2"

    if [ "$actual" != "$expected" ] ; then
        printf 'Expected: %q\n' "$expected"
        printf 'Actual:   %q\n' "$actual"
        hexdump -C <<<"$expected"
        hexdump -C <<<"$actual"
        exit 1
    fi
}

normalize() { tr -d "\n\r" ; }

check()
{
    local actual expected
    actual=$(echo "$2" | ("$DMD" -c -o- "$1" - 2>&1 || true) | normalize)
    compare "$actual" "$3"
}

expectedWithoutColor=__stdin.d\(2\):\ Error:\ no\ identifier\ for\ declarator\ \`test\`
expectedWithColor=$'\033'\[1m__stdin.d\(2\):\ $'\033'\[1\;31mError:\ $'\033'\[mno\ identifier\ for\ declarator\ $'\033'\[0\;36m$'\033'\[m$'\033'\[1mtest$'\033'\[0\;36m$'\033'\[m

check -c "test" "$expectedWithoutColor"
check -color=auto "test" "$expectedWithoutColor"
check -color=on "test" "$expectedWithColor"
check -color=off "test" "$expectedWithoutColor"

if [[ "$(script --version)" == script\ from\ util-linux\ * ]]
then
    actual="$(SHELL="$(command -v bash)" TERM="faketerm" script -q -c "echo test | ( $DMD -c -o- -)" /dev/null | normalize)" || true
    if [[ "$actual" != '^@^@'* ]] # 'script' weirdness on CircleCI
    then
        compare "$actual" "$expectedWithColor"
    fi
fi
