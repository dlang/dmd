# README For fail_compilation tests

Each file with a .d extension is run and is expected to fail to compile.
The diagnostic emitted must match the diagnostic in the test file,
and if it does, the test passes.

## Purpose

The point of these files is to test that the compiler produces a correct
diagnostic for each error message in the compiler's implementation.
The ideal is to achieve 100% coverage of the compiler source code.

A further aim is that when the compiler does fail these tests, the test case
should be crafted to make debugging the compiler as straightforward as practical.

## Guidelines

* Do not import any phobos or druntime files.
* If a test is added as a result of a bugzilla issue, include
a clickable URL to the corresponding bugzilla issue.
* It takes a long time to run these test. The run time corresponds with
the number of test files, not the size of the test file. Therefore, it makes
sense to group many tests into one file instead of multiple files.
By default, the compiler will only output up to 20 messages. This
can be increased via the switch `-verrors=<num>`
* Set off each set of tests in a file with `#line 100`, `#line 200`, etc.
This is so when lines are added or subtracted from the test file, all the
output line numbers do not have to be editted to match.
* Separate each set of tests in a file with at least:
 - a comment that is a row of stars
 - a `TEST_OUTPUT` section with the error messages that should be generated
 - a `#line ?00` directive
 - a URL pointing to the bugzilla issue
* Test cases should be as minimal and to the point as reasonable, to aid
in debugging the compiler.
* Do not rely on advanced compiler features when those features are not
relevant to the diagnostic being tested. Such dependencies make the compiler
harder to debug.

## See Also

[../README.md](https://github.com/dlang/dmd/blob/master/test/README.md) contains further information.
