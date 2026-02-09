// https://github.com/dlang/dmd/pull/XXXX
// Test that `is(__traits(getMember, T, "name") ...)` resolves member types
// without triggering full semantic analysis, which causes circular dependency
// errors when iterating allMembers on types with auto-return methods.

struct Column { string name; }

/****************************************************/
// 1. Basic: is(__traits(getMember, ...) == return) works for explicit return types
struct S
{
    int x;
    int foo() { return 42; }
}

// Bare getMember in is() resolves function return type
static assert(is(__traits(getMember, S, "foo") R == return) && is(R == int));

// Bare getMember in is() resolves field type
static assert(is(__traits(getMember, S, "x") == int));

/****************************************************/
// 2. Template struct: allMembers + is(getMember == return) with auto method
//    On HEAD, this causes "circular dependency" because getMember("save")
//    triggers functionSemantic3 for return type inference, and save()'s body
//    references hasIntReturning() which is being compiled.
struct Table(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static bool hasIntReturning()
    {
        static foreach (name; __traits(allMembers, Table))
        {{
            static if (is(__traits(getMember, Table, name) R == return))
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

static assert(!Table!int.hasIntReturning());

/****************************************************/
// 3. Mixin template: same pattern with mixin
mixin template Model(T)
{
    @Column("id") T id;

    static bool hasIntReturning()
    {
        alias This = typeof(this);
        static foreach (name; __traits(allMembers, This))
        {{
            static if (is(__traits(getMember, This, name) R == return))
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

struct User
{
    mixin Model!int;
    @Column("name") string name;
}

static assert(!User.hasIntReturning());

/****************************************************/
// 4. typeof(getMember) still works as before
static assert(is(typeof(__traits(getMember, S, "foo")) R == return) && is(R == int));
