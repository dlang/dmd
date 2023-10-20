# Scripted tests

Each D file is treated like a shell scripts which executes one or multiple
complex tests. The test result is indicated by the scripts exit code,

```
 0                the test was successful
 dshell.DISABLED  the test was skipped based on the environment
 *                the test failed
```

## Purpose

These scripts are intended to supports tests which cannot be implemented in any
other test category. For example, [this test](sameenv.d) verifies that the
process environment is propagated correctly to an executable run by `dmd -run`.

This can also be used to aggregate several such test cases into a new category
(e.g. as done for [DWARF debug info generation](dwarf.d)).

## Remarks

Scripts should prefer the following wrappers defined in the [`dshell`
module](../tools/dshell_prebuilt/dshell_prebuilt.d) instead of the plain
Phobos functions s.t. the test runner can issue a proper log on failure.

Note that `dshell` tests require additional code and linking another
executable, so they should be the last resort if a the test setup
cannot be represented in any other test category.

Refer to [test/README.md](../README.md) for general information and the
[test guidelines](../README.md#test-coding-practices).
