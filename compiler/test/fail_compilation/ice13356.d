/*
TEST_OUTPUT:
---
fail_compilation/ice13356.d(38): Error: template instance `Algebraic!(Tuple!(List))` recursive template expansion
    alias Payload = Algebraic!(
                    ^
fail_compilation/ice13356.d(21): Error: template instance `ice13356.isPrintable!(List)` error instantiating
    static if (isPrintable!(Types[0]))
               ^
fail_compilation/ice13356.d(39):        instantiated from here: `Tuple!(List)`
        Tuple!(List)
        ^
---
*/

struct Tuple(Types...)
{
    Types expand;
    alias expand this;

    static if (isPrintable!(Types[0]))
    {
    }
}

// T == Tuple!List, and accessing its .init will cause unresolved forward reference
enum bool isPrintable(T) = is(typeof({ T t; }));

struct Algebraic(AllowedTypesX...)
{
    alias AllowedTypes = AllowedTypesX;

    double x;   // dummy for the syntax Payload(d)
}

struct List
{
    alias Payload = Algebraic!(
        Tuple!(List)
    );

    Payload payload;

    this(double d) { payload = Payload(d); }
}

void main() {}
