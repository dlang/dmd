/*
REQUIRED_ARGS: -Jfail_compilation
TEST_OUTPUT:
---
fail_compilation\fail21227.d(2): Error: file `"/abs/path/to/file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227.d(2):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227.d(2):        [0]: `fail_compilation`
fail_compilation\fail21227.d(3): Error: file `"../file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227.d(3):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227.d(3):        [0]: `fail_compilation`
fail_compilation\fail21227.d(4): Error: file `"path/to/parent/../file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227.d(4):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227.d(4):        [0]: `fail_compilation`
---
 */
#line 1
enum val =
    import("/abs/path/to/file.txt") ~
    import("../file.txt") ~
    import("path/to/parent/../file.txt");
