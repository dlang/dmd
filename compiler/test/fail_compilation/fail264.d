/*
TEST_OUTPUT:
---
fail_compilation/fail264.d(12): Error: undefined identifier `undef`
    foreach (element; undef)
                      ^
---
*/

void main()
{
    foreach (element; undef)
    {
        fn(element);
    }
}

void fn(int i) {}
