// This should be solved by the header generator

#include "dcompat.h"
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

    return 0;
}
