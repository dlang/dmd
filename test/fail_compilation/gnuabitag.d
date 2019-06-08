// DISABLED: win32 win64

/*
TEST_OUTPUT:
---
fail_compilation/gnuabitag.d(35): Error: `@gnuAbiTag` at least one argument expected
fail_compilation/gnuabitag.d(38): Error: constructor `gnuabitag.gnuAbiTag.this` cannot be used because it is annotated with `@disable`
fail_compilation/gnuabitag.d(38): Error: `this` cannot be interpreted at compile time, because it has no available source code
fail_compilation/gnuabitag.d(41): Error: none of the overloads of `this` are callable using argument types `(string, wstring, dstring)`, candidates are:
fail_compilation/gnuabitag.d(26):        `gnuabitag.gnuAbiTag.this()`
fail_compilation/gnuabitag.d(28):        `gnuabitag.gnuAbiTag.this(string tag, string[] tags...)`
fail_compilation/gnuabitag.d(44): Error: `@gnuAbiTag()` char 0x99 not allowed in mangling
fail_compilation/gnuabitag.d(47): Error: none of the overloads of `this` are callable using argument types `(string, int, double)`, candidates are:
fail_compilation/gnuabitag.d(26):        `gnuabitag.gnuAbiTag.this()`
fail_compilation/gnuabitag.d(28):        `gnuabitag.gnuAbiTag.this(string tag, string[] tags...)`
fail_compilation/gnuabitag.d(51): Error: struct `gnuabitag.F` `@gnuAbiTag()` can only apply to C++ symbols
fail_compilation/gnuabitag.d(38): Error: `this` cannot be interpreted at compile time, because it has no available source code
---
*/

extern (D) struct gnuAbiTag
{
    string tag;
    string[] tags;

    @disable this();

    this(string tag, string[] tags...)
    {
        this.tag = tag;
        this.tags = tags;
    }
}

@gnuAbiTag
extern(C++) struct A {}

@gnuAbiTag()
extern(C++) struct B {}

@gnuAbiTag("a", "b"w, "c"d)
extern(C++) struct C {}

@gnuAbiTag("a\x99")
extern(C++) struct D {}

@gnuAbiTag("a", 2, 3.3)
extern(C++) struct E {}

@gnuAbiTag("a")
struct F {}
