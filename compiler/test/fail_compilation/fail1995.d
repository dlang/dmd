/*
REQUIRED_ARGS: -Jdoes_not_exists -Jfail_compilation/fail1995.d -Jfail_compilation/
TEST_OUTPUT:
---
fail_compilation/fail1995.d(14): Error: file `"SomeFile.txt"` cannot be found or not in a path specified with `-J`
immutable string Var = import("SomeFile.txt");
                       ^
fail_compilation/fail1995.d(14):        Path(s) searched (as provided by `-J`):
fail_compilation/fail1995.d(14):        [0]: `does_not_exists` (path not found)
fail_compilation/fail1995.d(14):        [1]: `fail_compilation/fail1995.d` (not a directory)
fail_compilation/fail1995.d(14):        [2]: `fail_compilation/`
---
 */
immutable string Var = import("SomeFile.txt");
