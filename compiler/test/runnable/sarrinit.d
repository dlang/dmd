int[0] a2 = (int[]).init;
int[1] a3 = (int[]).init;
int[][2] a4 = (int[][]).init;

// element initializer:
int[][2] a5 = null;
int[][2] a6 = (int[]).init;

void f()
{
    assert(a2 == []);
    assert(a3 == [0]);
    assert(a4 == [[], []]);
    assert(a5 == [[], []]);
    assert(a6 == [[], []]);
}
