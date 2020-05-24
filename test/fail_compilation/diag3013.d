/*
TEST_OUTPUT:
---
fail_compilation/diag3013.d(11): Error: cannot pass type `string` as a function argument
---
*/

int format(string, string, string) @system;

void main() {
    int s = string.format("abc", "def");
}
