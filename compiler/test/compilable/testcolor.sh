#!/usr/bin/env bash
set -eo pipefail

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

normalize()
{
    if uname | grep -qi "freebsd"; then
        tr -d "\n\r" | sed 's/void foo() {} void main() { goo(); }//; s/[[:space:]]\+\^$//'
    else
        tr -d "\n\r" | sed -E 's/void foo\(\) \{\} void main\(\) \{ goo\(\); \}//; s/\s+\^$//'
    fi
}

check()
{
    local actual expected
    actual=$(echo "$2" | ("$DMD" -c -o- -verrors=simple "$1" - 2>&1 || true) | normalize)
    compare "$actual" "$3"
}

expectedWithoutColor='__stdin.d(2): Error: variable name expected after type `test`, not `End of File`'
expectedWithColor=$'\E[1m__stdin.d(2): \E[1;31mError: \E[mvariable name expected after type `\E[0;36m\E[m\E[1mtest\E[0;36m\E[m`, not `\E[0;36m\E[m\E[1mEnd\E[0;36m \E[m\E[1mof\E[0;36m \E[m\E[1mFile\E[0;36m\E[m`'

check -c "test" "$expectedWithoutColor"
check -color=auto "test" "$expectedWithoutColor"
check -color=on "test" "$expectedWithColor"
check -color=off "test" "$expectedWithoutColor"

gooCode="void foo() {} void main() { goo(); }"
gooExpectedWithoutColor='__stdin.d(1): Error: undefined identifier `goo`, did you mean function `foo`?'
gooExpectedWithColor=$'\033[1m__stdin.d(1): \033[1;31mError: \033[mundefined identifier `\033[0;36m\033[m\033[1mgoo\033[0;36m\033[m`, did you mean function `\033[0;36m\033[m\033[1mfoo\033[0;36m\033[m`?'
check -color=on "$gooCode" "$gooExpectedWithColor"
check -color=off "$gooCode" "$gooExpectedWithoutColor"

if [[ "$(script --version)" == script\ from\ util-linux\ * ]]
then
    actual="$(SHELL="$(command -v bash)" TERM="faketerm" script -q -c "echo test | ( $DMD -c -o- -verrors=simple -)" /dev/null | normalize)" || true

    # Weird results for WSL, probably some environmental issue
    if uname -a | grep -i linux | grep -i microsoft &> /dev/null
    then
        echo "Skipping test because of WSL weirdness"
    elif [[ "$actual" != '^@^@'* ]] # 'script' weirdness on CircleCI
    then
        compare "$actual" "$expectedWithColor"
    fi
fi
