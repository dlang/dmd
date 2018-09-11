/*
TEST_OUTPUT:
---
fail_compilation/semanticCopyCtor.d(13): Error: copy constructor can only be a member of aggregate, not module `semanticCopyCtor`
fail_compilation/semanticCopyCtor.d(17): Error: the copy constructor parameter basic type needs to be `A`, not `int`
fail_compilation/semanticCopyCtor.d(20): Error: function `semanticCopyCtor.foo` cannot be marked with `@implicit` because it is not a copy constructor
fail_compilation/semanticCopyCtor.d(21): Error: variable `semanticCopyCtor.a` cannot be marked with `@implicit` because it is not a copy constructor
fail_compilation/semanticCopyCtor.d(30): Error: struct `C` cannot define both a postblit and copy constructor. Use the copy constructor.
fail_compilation/semanticCopyCtor.d(34): Error: struct `semanticCopyCtor.D` contains fields with postblits, therefore it cannot have a copy constructor.
---
*/
@implicit this(ref A another) {}

struct A
{
    @implicit this(ref int b) {}
}

@implicit void foo() {}
@implicit int a;

struct B
{
    this(this) {}
}

struct C
{
    this(this) {}
    @implicit this(ref C another) {}
}

struct D
{
    B b;
    @implicit this(ref D another) {}
}

