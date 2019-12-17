#!/usr/bin/env bash

# test @nogc exceptions
echo "void main() @nogc { throw new Exception(\"ex\"); }" | \
    $DMD -c -o- -preview=dip1008 - \

# test usage options
$DMD -preview='?' 2>&1 | grep -q "Upcoming language changes listed by -preview=name"
$DMD -preview=h 2>&1 | grep -q "=all              list information on all upcoming language changes"

$DMD -revert='?' 2>&1 | grep -q "Revertable language changes listed by -revert=name"
$DMD -revert=h 2>&1 | grep -q "=all              list information on all revertable language changes"

$DMD -transition='?' 2>&1 | grep "Language transitions listed by -transition=name"
$DMD -transition=h 2>&1 | grep "=all              list information on all language transitions"
