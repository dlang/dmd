# Tests for successful compilation

Each D file will be compiled and the compilation is expected to succeed.
Any diagnostic emitted must match the predefined diagnostic in the test
file, otherwise the test will fail.

## Purpose

The point of these files is to test that the compiler successfully emits
code without unexpected diagnostics or potential crashes.

A further aim is that when the compiler does fail these tests, the test case
should be crafted to make debugging the compiler as straightforward as practical.

## Remarks

Test in this directory are not linked by default because linking is expensive
and usually not necessary to reproduce an error. A test may specify the `LINK`
test parameter to enforce the linking.

Refer to [test/README.md](../README.md) for general information and the
[test guidelines](../README.md#test-coding-practices).
