/*
TEST_OUTPUT:
---
fail_compilation/ice14642.d(29): Error: no property `func` for `p` of type `ice14642.Y*`
fail_compilation/ice14642.d(24): Error: template instance `ice14642.X.NA!()` error instantiating
fail_compilation/ice14642.d(48): Error: undefined identifier `errorValue`
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
