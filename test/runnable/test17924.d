// PERMUTE_ARGS:

void main()
{
    int x = 0;
    int y = 1;
    assert((x ?: y) == y);
    assert((y ?: x) == y);

    int* p;
    int u;
    assert((p ?: &u) == &u);
    assert((&u ?: p) == &u);

    class C
    {
        int a;
        this(int a) { this.a = a; }
    }

    C inst = new C(1);
    C not_inst;
    assert((not_inst ?: inst).a == inst.a);
    assert((inst ?: not_inst).a == inst.a);
}
