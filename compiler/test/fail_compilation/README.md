# Tests for diagnostics on compilation failure

Each D file will be compiled and the compilation is expected to fail
with exit code 1. The diagnostic emitted must match the predefined
diagnostic in the test file, otherwise the test will fail.

## Purpose

The point of these files is to test that the compiler produces a correct
diagnostic for each error message in the compiler's implementation.

A further aim is that when the compiler does fail these tests, the test case
should be crafted to make debugging the compiler as straightforward as practical.

## Remarks

Every test in this directory is compiled with `-verrors=0` s.t. all error
messages will be issued.

Refer to [test/README.md](../README.md) for general information and the
 [test guidelines](../README.md#test-coding-practices).
