#include "library.h"

#include <assert.h>

int main()
{
    char name[] = "Header";
    const int length = sizeof(name) - 1;

    C* c = C::create(name, length);
    assert(c);
    assert(c->s.i == length);
    assert(!c->s.b);
    assert(c->name.ptr == name);
    assert(c->name.length == length);
    assert(c->name[1] == 'e');
    assert(const_cast<const C*>(c)->name[2] == 'a');
    c->verify();

    assert(foo(c->s) == bar(c));

    c->s.multiply(c->s);
    assert(c->s.i == length * length);
    assert(c->s.b);

    U u;
    u.b = false;
    toggle(u);
    assert(u.b);

    assert(3 <= PI && PI <= 4);
    assert(counter = 42);

    assert(Weather::Sun != Weather::Rain);
    assert(Weather::Rain != Weather::Storm);

    S2 s2;
    s2.s = c->s;

    WithTuple wt = createTuple();
    // printf("\n(%d, %f)\n\n", wt.__memberTuple_field_0, wt.__memberTuple_field_1);
    assert(wt.__memberTuple_field_0_ == 1);
    assert(wt.__memberTuple_field_1_ == 2.0);

    // printf("\n(%d, %f)\n\n", __globalTuple_field_0, __globalTuple_field_1);
    // Omitted because a leading __ implies a reserved name
    // assert(__globalTuple_field_0 == 3);
    // assert(__globalTuple_field_1 == 4.0);

    tupleFunction(5, 6.0);

    assert(vtable->callable_2() == 2);
    assert(vtable->callable_4() == 4);
    assert(vtable->callable_6() == 6);

#if !defined(_WIN64)
    // The call segfaults on Win64, probably an unrelated (ABI?) bug
    assert(templated(Templated<int>(4)).t == 4);
#endif

    int i;
    assert(&i == inoutFunc(&i));

    InvalidNames<Pass> invalidNames;
    invalidNames.register_ = Pass::inline_;
    invalidNames.foo(Pass::inline_);

    return 0;
}
