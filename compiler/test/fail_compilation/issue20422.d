// https://issues.dlang.org/show_bug.cgi?id=20422

/*
REQUIRED_ARGS: -m32
TEST_OUTPUT:
---
fail_compilation/issue20422.d(13): Error: missing length argument for array
fail_compilation/issue20422.d(14): Error: negative array dimension `-1`
---
*/

void main() {
    new int[];
    new int[-1];
}
