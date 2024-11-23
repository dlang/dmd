// https://issues.dlang.org/show_bug.cgi?id=20422

/*
REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/issue20422.d(23): Error: missing length argument for array
    new int[];
    ^
fail_compilation/issue20422.d(24): Error: negative array dimension `-1`
    new int[-1];
    ^
fail_compilation/issue20422.d(25): Error: negative array dimension `-2147483648`
    new int[](int.min);
    ^
fail_compilation/issue20422.d(26): Error: too many arguments for array
    new int[](1, 2);
    ^
---
*/

void main() {
    new int[];
    new int[-1];
    new int[](int.min);
    new int[](1, 2);
}
