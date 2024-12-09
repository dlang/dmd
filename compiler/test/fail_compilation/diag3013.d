/*
TEST_OUTPUT:
---
fail_compilation/diag3013.d(13): Error: cannot pass type `string` as a function argument
    int s = string.format("abc", "def");
            ^
---
*/

int format(string, string, string);

void main() {
    int s = string.format("abc", "def");
}
