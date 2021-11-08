/*
REQUIRED_ARGS: -Jfail_compilation
DISABLED: linux osx freebsd dragonflybsd netbsd openbsd
TEST_OUTPUT:
---
fail_compilation\fail21227_win.d(2): Error: absolute path is not allowed in import expression: `"\\\\UNC\\path\\to\\file.txt"`
fail_compilation\fail21227_win.d(3): Error: absolute path is not allowed in import expression: `"c:file.txt"`
fail_compilation\fail21227_win.d(4): Error: absolute path is not allowed in import expression: `"c:\\file.txt"`
fail_compilation\fail21227_win.d(5): Error: absolute path is not allowed in import expression: `"c:/file.txt"`
fail_compilation\fail21227_win.d(6): Error: absolute path is not allowed in import expression: `"\\abs\\path\\to\\file.txt"`
fail_compilation\fail21227_win.d(7): Error: absolute path is not allowed in import expression: `"/abs/path/to/file.txt"`
fail_compilation\fail21227_win.d(8): Error: path refers to parent (`..`) directory: `"..\\file.txt"`
fail_compilation\fail21227_win.d(9): Error: path refers to parent (`..`) directory: `"../file.txt"`
fail_compilation\fail21227_win.d(10): Error: path refers to parent (`..`) directory: `"path\\to\\parent\\..\\file.txt"`
fail_compilation\fail21227_win.d(11): Error: path refers to parent (`..`) directory: `"path/to/parent/../file.txt"`
fail_compilation\fail21227_win.d(12): Error: `"file>txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(12):        Character `'>'` is reserved and cannot be used
fail_compilation\fail21227_win.d(13): Error: `"file<txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(13):        Character `'<'` is reserved and cannot be used
fail_compilation\fail21227_win.d(14): Error: `"file:txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(14):        Character `':'` is reserved and cannot be used
fail_compilation\fail21227_win.d(15): Error: `"file\"txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(15):        Character `'"'` is reserved and cannot be used
fail_compilation\fail21227_win.d(16): Error: `"file|txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(16):        Character `'|'` is reserved and cannot be used
fail_compilation\fail21227_win.d(17): Error: `"file?txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(17):        Character `'?'` is reserved and cannot be used
fail_compilation\fail21227_win.d(18): Error: `"file*txt"` is  not a valid filename on this platform
fail_compilation\fail21227_win.d(18):        Character `'*'` is reserved and cannot be used
fail_compilation\fail21227_win.d(19): Error: file `"do_not_exist"` cannot be found or not in a path specified with `-J`
fail_compilation\fail21227_win.d(19):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(19):        [0]: `fail_compilation`
---
 */
#line 1
enum val =
    import(r"\\UNC\path\to\file.txt") ~
    import(r"c:file.txt") ~
    import(r"c:\file.txt") ~
    import(r"c:/file.txt") ~
    import(r"\abs\path\to\file.txt") ~
    import(r"/abs/path/to/file.txt") ~
    import(r"..\file.txt") ~
    import(r"../file.txt") ~
    import(r"path\to\parent\..\file.txt") ~
    import(r"path/to/parent/../file.txt") ~
    import(r"file>txt") ~
    import(r"file<txt") ~
    import(r"file:txt") ~
    import( `file"txt`) ~
    import(r"file|txt") ~
    import(r"file?txt") ~
    import(r"file*txt") ~
    import(r"do_not_exist")
;
