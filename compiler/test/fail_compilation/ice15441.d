/*
TEST_OUTPUT:
---
fail_compilation/ice15441.d(26): Error: `s1.front` is `void` and has no value
    foreach (p, e; s1) {}
    ^
fail_compilation/ice15441.d(29): Error: cannot infer argument types, expected 1 argument, not 2
    foreach (p, e; s2) {}
    ^
---
*/

struct S1
{
    auto front()() {}
}

struct S2
{
    auto front()() { return 1; }
}

void main()
{
    S1 s1;
    foreach (p, e; s1) {}

    S2 s2;
    foreach (p, e; s2) {}
}
