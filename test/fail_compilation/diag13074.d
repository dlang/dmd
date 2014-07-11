/*
TEST_OUTPUT:
---
fail_compilation/diag13074.d(29): Error: AA key type S now requires equality rather than comparison
fail_compilation/diag13074.d(29):        Please define opEquals, or remove opCmp to also rely on default memberwise comparison.
---
*/
struct S
{
    int x;
    int y;

    int opCmp(ref const S other) const
    {
        return x < other.x ? -1 : x > other.x ? 1 : 0;
    }
    hash_t toHash() const
    {
        return x;
    }
}

void main()
{
    S s1 = S(1, 1);
    S s2 = S(1, 2);
    S s3 = S(2, 1);
    S s4 = S(2, 2);
    bool[S] arr;
    arr[s1] = true;
    arr[s2] = true;
    arr[s3] = true;
    arr[s4] = true;
}
