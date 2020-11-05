/*
REQUIRED_ARGS: -Jfail_compilation
DISABLED: win
TEST_OUTPUT:
---
fail_compilation/fail21227_posix.d(2): Error: absolute path is not allowed in import expression: `"/abs/path/to/file.txt"`
fail_compilation/fail21227_posix.d(3): Error: path refers to parent (`..`) directory: `"../file.txt"`
fail_compilation/fail21227_posix.d(4): Error: path refers to parent (`..`) directory: `"path/to/parent/../file.txt"`
fail_compilation/fail21227_posix.d(5): Error: file `"do_not_exist"` cannot be found or not in a path specified with `-J`
fail_compilation/fail21227_posix.d(5):        Path(s) searched (as provided by `-J`):
fail_compilation/fail21227_posix.d(5):        [0]: `fail_compilation`
---
 */
#line 1
enum val =
    import("/abs/path/to/file.txt") ~
    import("../file.txt") ~
    import("path/to/parent/../file.txt") ~
    import("do_not_exist")
;
