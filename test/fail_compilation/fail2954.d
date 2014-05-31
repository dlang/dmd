/*
TEST_OUTPUT:
---
fail_compilation/fail2954.d(13): Error: associative arrays can only be assigned values with immutable keys, not char[]
fail_compilation/fail2954.d(16): Error: associative arrays can only be assigned values with immutable keys, not const(char[])
---
*/
void main()
{
    uint[string] hash;
    char[] a = "abc".dup;

    hash[a] = 42;

    const ca = a;
    hash[ca] = 42;

    a[0] = 'A';
    //writeln(hash.keys);
}
