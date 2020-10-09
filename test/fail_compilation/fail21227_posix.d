/*
REQUIRED_ARGS: -Jfail_compilation
DISABLED: win
TEST_OUTPUT:
---
fail_compilation/fail21227_posix.d(2): Error: absolute path is not allowed in import expression: `"/abs/path/to/file.txt"`
fail_compilation/fail21227_posix.d(3): Error: path refers to parent (`..`) directory: `"../file.txt"`
fail_compilation/fail21227_posix.d(4): Error: path refers to parent (`..`) directory: `"path/to/parent/../file.txt"`
---
 */
#line 1
enum val =
    import("/abs/path/to/file.txt") ~
    import("../file.txt") ~
    import("path/to/parent/../file.txt");
