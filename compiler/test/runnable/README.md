# Tests for successful code generation

Each D file will be compiled and the compilation is expected to succeed.
Any diagnostic emitted must match the predefined diagnostic in the test
file, otherwise the test will fail.

All compiled executables will be run and are expected to finish successfully
with exit code 0. Any output from those binaries must be defined via the
[`RUN_OUTPUT` parameter](../README.md#test-configuration).

## Purpose

The point of these files is to test that the compiler emits valid code
whose behaviour matches the language specification.

## Remarks

Every test in this directory will be executed for all permutations of the
arguments provided in the [`ARGS` environment variable](../README.md#environment-variables)
unless override by the [`PERMUTE_ARGS` test parameter](../README.md#test-configuration).

This means that adding tests in this directory can noticeably increase
the time required to run the test suite. Hence every test should consider
whether running the executable or processing all permutations is beneficial
to increase the test coverage.

Refer to [test/README.md](../README.md) for general information and the
[test guidelines](../README.md#test-coding-practices).
