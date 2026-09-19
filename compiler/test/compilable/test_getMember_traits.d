/*
 * New lightweight traits for member introspection that avoid triggering full
 * expressionSemantic/functionSemantic on the target member. This prevents
 * circular dependency errors when iterating allMembers on types with
 * auto-return methods that reference the introspecting function at compile time.
 *
 * __traits(getMemberAttributes, T, "name") — lightweight UDA retrieval
 * __traits(getMemberType, T, "name")       — lightweight type retrieval
 */

struct Column { string name; }

/****************************************************/
// 1. getMemberAttributes: basic UDA retrieval
struct S1
{
    @Column("id") int x;
    @(42) string y;
    int foo() { return 0; }
}

static assert(__traits(getMemberAttributes, S1, "x").length == 1);
static assert(__traits(getMemberAttributes, S1, "x")[0] == Column("id"));
static assert(__traits(getMemberAttributes, S1, "y").length == 1);
static assert(__traits(getMemberAttributes, S1, "y")[0] == 42);
static assert(__traits(getMemberAttributes, S1, "foo").length == 0);

/****************************************************/
// 2. getMemberAttributes: template struct with auto method (circular dep case)
//    Using __traits(getAttributes, __traits(getMember, ...)) on HEAD causes
//    "circular dependency" when allMembers iteration hits an auto-return method
//    whose body references the introspecting function.
struct Table(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static string[] columnNames()
    {
        string[] result;
        static foreach (name; __traits(allMembers, Table))
        {{
            static foreach (attr; __traits(getMemberAttributes, Table, name))
            {
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

static assert(Table!int.columnNames() == ["id", "data"]);

/****************************************************/
// 3. getMemberAttributes: mixin template
mixin template Model()
{
    static string[] modelColumnNames()
    {
        string[] result;
        static foreach (name; __traits(allMembers, typeof(this)))
        {{
            static foreach (attr; __traits(getMemberAttributes, typeof(this), name))
            {
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
// 4. getMemberType: basic — extract return type
struct S2
{
    int x;
    int foo() { return 42; }
}

static assert(is(__traits(getMemberType, S2, "foo") R == return) && is(R == int));

/****************************************************/
// 5. getMemberType: basic — check field type
static assert(is(__traits(getMemberType, S2, "x") == int));

/****************************************************/
// 6. getMemberType: basic — check function type
static assert(is(__traits(getMemberType, S2, "foo") == function));

/****************************************************/
// 7. getMemberType: template struct with auto method (circular dep case)
//    Using is(__traits(getMember, ...)) on HEAD causes "circular dependency"
//    for the same reason as case 2.
struct Table2(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static bool hasIntReturning()
    {
        static foreach (name; __traits(allMembers, Table2))
        {{
            static if (is(__traits(getMemberType, Table2, name) R == return))
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
// 8. getMemberType: mixin template
mixin template Model2(T)
{
    @Column("id") T id;

    static bool hasIntReturning()
    {
        alias This = typeof(this);
        static foreach (name; __traits(allMembers, This))
        {{
            static if (is(__traits(getMemberType, This, name) R == return))
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
// 9. typeof(getMember) still works as before
static assert(is(typeof(__traits(getMember, S2, "foo")) R == return) && is(R == int));
