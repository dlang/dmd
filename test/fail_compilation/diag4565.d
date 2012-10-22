// REQUIRED_ARGS: -m32
/*
TEST_OUTPUT:
---
fail_compilation/diag4565.d(1): Error: cannot implicitly convert array literal [1,2,3] to int[1u][3u]
fail_compilation/diag4565.d(2): Error: cannot implicitly convert array literal [[1],2,3] to int[1u][3u]
fail_compilation/diag4565.d(3): Error: cannot implicitly convert array literal [[1],[2],3] to int[1u][3u]
fail_compilation/diag4565.d(4): Error: cannot implicitly convert array literal [[3],4] to int[1u][2u]
fail_compilation/diag4565.d(4): Error: cannot implicitly convert array literal [[[1],[2]],[[2],[3]],__error] to int[1u][2u][3u]
fail_compilation/diag4565.d(5): Error: cannot implicitly convert array literal [1,[2]] to int[1u][2u]
fail_compilation/diag4565.d(5): Error: cannot implicitly convert array literal [[3],4] to int[1u][2u]
fail_compilation/diag4565.d(5): Error: cannot implicitly convert array literal [__error,[[2],[3]],__error] to int[1u][2u][3u]
---
*/

#line 1
int[1][3] b1 = [1, 2, 3];
int[1][3] b2 = [[1], 2, 3];
int[1][3] b3 = [[1], [2], 3];
int[1][2][3] b4 = [[[1], [2]], [[2], [3]], [[3], 4]];
int[1][2][3] b5 = [[1, [2]], [[2], [3]], [[3], 4]];

void main() { }
