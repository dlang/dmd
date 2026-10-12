/*
 * Test that __traits(getMember, ...) resolves members via lightweight symbol
 * lookup without triggering full expressionSemantic. This avoids eager body
 * compilation (functionSemantic3) which causes circular dependency errors
 * when iterating allMembers on types with auto-return methods.
 */

struct Column { string name; }

/****************************************************/
// 1. getAttributes(getMember(...)) - template struct

struct Table1(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static string[] columnNames()
    {
        string[] result;
        static foreach (name; __traits(allMembers, Table1)) {{
            static foreach (attr; __traits(getAttributes, __traits(getMember, Table1, name))) {
                static if (is(typeof(attr) == Column))
                    result ~= attr.name;
            }
        }}
        return result;
    }

    auto save()
    {
        enum cols = columnNames();
        return cols.length;
    }
}

static assert(Table1!int.columnNames() == ["id", "data"]);

/****************************************************/
// 2. getAttributes(getMember(...)) - mixin template

mixin template Model()
{
    static string[] modelColumnNames()
    {
        string[] result;
        static foreach (name; __traits(allMembers, typeof(this))) {{
            static foreach (attr; __traits(getAttributes, __traits(getMember, typeof(this), name))) {
                static if (is(typeof(attr) == Column))
                    result ~= attr.name;
            }
        }}
        return result;
    }

    auto persist()
    {
        enum cols = modelColumnNames();
        return cols.length;
    }
}

struct User
{
    @Column("user_id") int id;
    @Column("username") string name;
    mixin Model;
}

static assert(User.modelColumnNames() == ["user_id", "username"]);

/****************************************************/
// 3. typeof(getMember(...)) - basic

struct S
{
    int x;
    int foo() { return 42; }
}

static assert(is(typeof(__traits(getMember, S, "foo")) R == return) && is(R == int));
static assert(is(typeof(__traits(getMember, S, "x")) == int));

/****************************************************/
// 4. typeof(getMember(...)) - template struct circular dep

struct Table2(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static bool hasIntReturning()
    {
        static foreach (name; __traits(allMembers, Table2))
        {{
            static if (is(typeof(__traits(getMember, Table2, name)) R == return))
            {
                static if (is(R == int))
                    return true;
            }
        }}
        return false;
    }

    auto save()
    {
        enum h = hasIntReturning();
        return h ? 1 : 0;
    }
}

static assert(!Table2!int.hasIntReturning());

/****************************************************/
// 5. typeof(getMember(...)) - mixin template circular dep

mixin template Model2(T)
{
    @Column("id") T id;

    static bool hasIntReturning()
    {
        alias This = typeof(this);
        static foreach (name; __traits(allMembers, This))
        {{
            static if (is(typeof(__traits(getMember, This, name)) R == return))
            {
                static if (is(R == int))
                    return true;
            }
        }}
        return false;
    }

    auto save()
    {
        enum h = hasIntReturning();
        return h ? 1 : 0;
    }
}

struct User2
{
    mixin Model2!int;
    @Column("name") string name;
}

static assert(!User2.hasIntReturning());

/****************************************************/
// 6. alias + typeof(getMember(...)) - template parameter pattern

struct SetInfo(T) {
    T value;
}

struct Settings {
    SetInfo!(string[string]) defaultRunEnvironments;
    int x;
}

template FieldRef(alias T, string name) {
    alias Ref = __traits(getMember, T, name);
    alias Type = typeof(Ref);
}

alias FR = FieldRef!(Settings, "defaultRunEnvironments");
static assert(is(FR.Type == SetInfo!(string[string])));

/****************************************************/
// 7. AliasSeq(getMember(...)) - non-auto function in template struct

struct Slice(T, size_t N)
{
    T _iterator;
    size_t[N] _lengths;

    ptrdiff_t indexStrideValue(ptrdiff_t n) @safe scope const
    {
        return n;
    }

    auto save() { return this; }
}

import std.meta : AliasSeq;

template isSingleMember(T, string member)
{
    enum isSingleMember = AliasSeq!(__traits(getMember, T, member)).length == 1;
}

static assert(isSingleMember!(Slice!(double*, 2), "indexStrideValue"));

/****************************************************/
// 8. getMember(...).mangleof - should produce full symbol mangling

struct S2(T)
{
    static void f()
    {
    }
}

static assert(__traits(getMember, S2!int, "f").mangleof ==
    S2!int.f.mangleof);

/****************************************************/
// 9. getMember(...)() - CTFE call through getMember

struct S3(T)
{
    static int f()
    {
        return 42;
    }
}

static assert(__traits(getMember, S3!int, "f")() == 42);

/****************************************************/
// 10. &getMember(...) - taking address of getMember result

struct S4(T)
{
    static int f()
    {
        return 42;
    }
}

enum fp = &__traits(getMember, S4!int, "f");
static assert(fp() == 42);
