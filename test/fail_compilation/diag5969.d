/*
TEST_OUTPUT:
---
fail_compilation/diag5969.d(17): Error: .tupleof of a type cannot be used as a foreach expression. Wrap it inside a typeof() if intended.
fail_compilation/diag5969.d(17): Error: invalid foreach aggregate tuple((F).a, (F).b)
---
*/

struct F
{
    int a;
    float b;
}

int foo()
{
    foreach (_; F.tupleof) { }
    return 1;
}

void main() { foo(); }
