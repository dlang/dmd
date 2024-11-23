/*
TEST_OUTPUT:
---
fail_compilation/test23170.d(12): Error: array literal in `@nogc` delegate `test23170.__lambda_L12_C15` may cause a GC allocation
enum lambda = () => badAlias([1, 2, 3]);
                             ^
---
*/
// https://issues.dlang.org/show_bug.cgi?id=23170

@nogc:
enum lambda = () => badAlias([1, 2, 3]);
alias badAlias = (int[] array) => id(array);
int[] id(int[] array) { return array; }
