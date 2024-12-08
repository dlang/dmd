/*
TEST_OUTPUT:
---
fail_compilation/ice14642.d(51): Error: undefined identifier `errorValue`
enum errVal = errorValue;
              ^
fail_compilation/ice14642.d(27): Error: template instance `ice14642.X.NA!()` error instantiating
    alias na = NA!();
               ^
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
