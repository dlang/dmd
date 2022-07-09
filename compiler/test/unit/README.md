# Extended unit tests

Tests in this directory will be compiled into a single executable which links with
the DMD frontend and runs all `unittest` blocks defined in this directory.

## Purpose

These tests are intended to test single components (e.g. the lexer) in isolation
instead of relying on full end-to-end tests as done for `compilable`, ... .

## Remarks

Refer to [test/README.md](../README.md) for general information and the
[test guidelines](../README.md#test-coding-practices).
