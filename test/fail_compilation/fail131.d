/*
TEST_OUTPUT:
---
fail_compilation/fail131.d(9): Deprecation: function D main use main(string[]) instead of main(char[][])
fail_compilation/fail131.d(9): Error: function D main parameters must be main() or main(string[] args)
---
*/

int main(lazy char[][] args)
{
    return args.length;
}
