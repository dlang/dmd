#!/usr/bin/env bash

$DMD --version

echo 'import bar;' > foo.d
touch bar.d
echo 'foo.o: bar.d' > expected.deps
$DMD -o- -makefiledeps=actual.deps foo.d
diff_output=$(diff actual.deps expected.deps)
diff_result=$?
echo "diff_result: $diff_result"

# rm foo.d bar.d actual.deps expected.deps


exit $diff_result
