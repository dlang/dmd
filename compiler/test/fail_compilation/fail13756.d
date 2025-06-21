/*
TEST_OUTPUT:
---
fail_compilation/fail13756.d(16): Error: `foreach`: index parameter `ref k` must be type `const(int)`, not `int`
fail_compilation/fail13756.d(19): Error: `foreach`: index parameter `key` must be type `int`, not `string`
fail_compilation/fail13756.d(21): Error: `foreach`: value parameter `val` must be type `int`, not `char`
fail_compilation/fail13756.d(22): Error: `foreach`: value parameter `ref val` must be type `int`, not `dchar`
fail_compilation/fail13756.d(25): Error: `foreach`: index parameter `key` must be type `int`, not `ulong`
fail_compilation/fail13756.d(26): Error: `foreach`: value parameter `val` must be type `int`, not `ulong`
---
*/

void maiin()
{
    int[int] aa = [1:2];
    foreach (ref int k, v; aa)
    {
    }
    foreach (string key, val; aa) {}

    foreach (key, char val; aa) {}
    foreach (key, ref dchar val; aa) {}

    // following not supported yet
    foreach (ulong key, val; aa) {}
    foreach (key, ulong val; aa) {}
}
