
/*
TEST_OUTPUT:
---
fail_compilation/parseStc4.d(48): Error: redundant attribute `pure`
pure nothrow @system @nogc @property
^
fail_compilation/parseStc4.d(48): Error: redundant attribute `nothrow`
pure nothrow @system @nogc @property
     ^
fail_compilation/parseStc4.d(48): Error: conflicting attribute `@system`
pure nothrow @system @nogc @property
              ^
fail_compilation/parseStc4.d(48): Error: redundant attribute `@nogc`
pure nothrow @system @nogc @property
                      ^
fail_compilation/parseStc4.d(48): Error: redundant attribute `@property`
pure nothrow @system @nogc @property
                            ^
fail_compilation/parseStc4.d(55): Error: redundant attribute `const`
    const this(int) const {}
                    ^
fail_compilation/parseStc4.d(56): Error: redundant attribute `const`
    const this(this) const {}
                     ^
fail_compilation/parseStc4.d(56): Deprecation: `const` postblit is deprecated. Please use an unqualified postblit.
    const this(this) const {}
                           ^
fail_compilation/parseStc4.d(57): Error: redundant attribute `const`
    const ~this() const {}
                  ^
fail_compilation/parseStc4.d(59): Error: redundant attribute `pure`
    pure static this() pure {}
                       ^
fail_compilation/parseStc4.d(60): Error: redundant attribute `@safe`
    @safe static ~this() @safe {}
                          ^
fail_compilation/parseStc4.d(61): Error: redundant attribute `nothrow`
    nothrow shared static this() nothrow {}
                                 ^
fail_compilation/parseStc4.d(62): Error: conflicting attribute `@trusted`
    @system shared static ~this() @trusted {}
                                   ^
---
*/
pure nothrow @safe   @nogc @property
int foo()
pure nothrow @system @nogc @property
{
    return 0;
}

struct S
{
    const this(int) const {}
    const this(this) const {}
    const ~this() const {}

    pure static this() pure {}
    @safe static ~this() @safe {}
    nothrow shared static this() nothrow {}
    @system shared static ~this() @trusted {}
}
