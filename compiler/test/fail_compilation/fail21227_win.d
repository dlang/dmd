/*
REQUIRED_ARGS: -Jfail_compilation
DISABLED: linux osx freebsd dragonflybsd netbsd openbsd
TEST_OUTPUT:
---
fail_compilation\fail21227_win.d(74): Error: absolute path is not allowed in import expression: `"\\\\UNC\\path\\to\\file.txt"`
    import(r"\\UNC\path\to\file.txt") ~
    ^
fail_compilation\fail21227_win.d(75): Error: absolute path is not allowed in import expression: `"c:file.txt"`
    import(r"c:file.txt") ~
    ^
fail_compilation\fail21227_win.d(76): Error: absolute path is not allowed in import expression: `"c:\\file.txt"`
    import(r"c:\file.txt") ~
    ^
fail_compilation\fail21227_win.d(77): Error: absolute path is not allowed in import expression: `"c:/file.txt"`
    import(r"c:/file.txt") ~
    ^
fail_compilation\fail21227_win.d(78): Error: absolute path is not allowed in import expression: `"\\abs\\path\\to\\file.txt"`
    import(r"\abs\path\to\file.txt") ~
    ^
fail_compilation\fail21227_win.d(79): Error: absolute path is not allowed in import expression: `"/abs/path/to/file.txt"`
    import(r"/abs/path/to/file.txt") ~
    ^
fail_compilation\fail21227_win.d(80): Error: path refers to parent (`..`) directory: `"..\\file.txt"`
    import(r"..\file.txt") ~
    ^
fail_compilation\fail21227_win.d(81): Error: path refers to parent (`..`) directory: `"../file.txt"`
    import(r"../file.txt") ~
    ^
fail_compilation\fail21227_win.d(82): Error: path refers to parent (`..`) directory: `"path\\to\\parent\\..\\file.txt"`
    import(r"path\to\parent\..\file.txt") ~
    ^
fail_compilation\fail21227_win.d(83): Error: path refers to parent (`..`) directory: `"path/to/parent/../file.txt"`
    import(r"path/to/parent/../file.txt") ~
    ^
fail_compilation\fail21227_win.d(84): Error: `"file>txt"` is not a valid filename on this platform
    import(r"file>txt") ~
    ^
fail_compilation\fail21227_win.d(84):        Character `'>'` is reserved and cannot be used
fail_compilation\fail21227_win.d(85): Error: `"file<txt"` is not a valid filename on this platform
    import(r"file<txt") ~
    ^
fail_compilation\fail21227_win.d(85):        Character `'<'` is reserved and cannot be used
fail_compilation\fail21227_win.d(86): Error: `"file:txt"` is not a valid filename on this platform
    import(r"file:txt") ~
    ^
fail_compilation\fail21227_win.d(86):        Character `':'` is reserved and cannot be used
fail_compilation\fail21227_win.d(87): Error: `"file\"txt"` is not a valid filename on this platform
    import( `file"txt`) ~
    ^
fail_compilation\fail21227_win.d(87):        Character `'"'` is reserved and cannot be used
fail_compilation\fail21227_win.d(88): Error: `"file|txt"` is not a valid filename on this platform
    import(r"file|txt") ~
    ^
fail_compilation\fail21227_win.d(88):        Character `'|'` is reserved and cannot be used
fail_compilation\fail21227_win.d(89): Error: `"file?txt"` is not a valid filename on this platform
    import(r"file?txt") ~
    ^
fail_compilation\fail21227_win.d(89):        Character `'?'` is reserved and cannot be used
fail_compilation\fail21227_win.d(90): Error: `"file*txt"` is not a valid filename on this platform
    import(r"file*txt") ~
    ^
fail_compilation\fail21227_win.d(90):        Character `'*'` is reserved and cannot be used
fail_compilation\fail21227_win.d(91): Error: file `"do_not_exist"` cannot be found or not in a path specified with `-J`
    import(r"do_not_exist")
    ^
fail_compilation\fail21227_win.d(91):        Path(s) searched (as provided by `-J`):
fail_compilation\fail21227_win.d(91):        [0]: `fail_compilation`
---
*/

// Line 74 starts here
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
