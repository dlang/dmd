/*
TEST_OUTPUT:
---
fail_compilation/ice14642.d(48): Error: undefined identifier `errorValue`
fail_compilation/ice14642.d(52):        error on member `ice14642.Z.v`
fail_compilation/ice14642.d(24): Error: template instance `ice14642.X.NA!()` error instantiating
---
*/

alias TypeTuple(T...) = T;

struct X
{
    static struct NA()
    {
        X x;

        void check()
        {
            x.func();
        }
    }

    alias na = NA!();

    auto func()
    {
        Y* p;
        p.func();
    }
}

struct Y
{
    mixin Mix;
}

template Mix()
{
    void func()
    {
        auto z = Z(null);
    }
}

struct Type(size_t v) {}

enum errVal = errorValue;

struct Z
{
    Type!errVal v;
}
