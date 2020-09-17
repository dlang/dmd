/*
REQUIRED_ARGS: -Jfail_compilation
DISABLED: linux osx freebsd dragonflybsd netbsd
TEST_OUTPUT:
---
fail_compilation\fail21227_win.d(2): Error: file `"\\\\UNC\\path\\to\\file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(2):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(2):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(3): Error: file `"c:file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(3):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(3):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(4): Error: file `"c:\\file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(4):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(4):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(5): Error: file `"c:/file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(5):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(5):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(6): Error: file `"\\abs\\path\\to\\file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(6):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(6):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(7): Error: file `"..\\file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(7):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(7):        [0]: `fail_compilation`
fail_compilation\fail21227_win.d(8): Error: file `"path\\to\\parent\\..\\file.txt"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(8):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(8):        [0]: `fail_compilation`
---
 */
#line 1
enum val =
    import(r"\\UNC\path\to\file.txt") ~
    import(r"c:file.txt") ~
    import(r"c:\file.txt") ~
    import(r"c:/file.txt") ~
    import(r"\abs\path\to\file.txt") ~
    import(r"..\file.txt") ~
    import(r"path\to\parent\..\file.txt");
