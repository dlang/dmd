/*
TEST_OUTPUT:
---
fail_compilation/ice11553.d(26): Error: recursive template expansion while looking for `A!().A()`
static if (A!B) {}
           ^
fail_compilation/ice11553.d(26): Error: expression `A()` of type `void` does not have a boolean value
static if (A!B) {}
           ^
---
*/

template A(alias T)
{
    template A()
    {
        alias A = T!();
    }
}

template B()
{
    alias B = A!(.B);
}

static if (A!B) {}
