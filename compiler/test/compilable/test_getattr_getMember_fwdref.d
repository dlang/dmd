/*
 * __traits(getAttributes, __traits(getMember, ...)) should resolve member UDAs
 * via lightweight symbol lookup without triggering full expressionSemantic on the
 * member. This avoids eager body compilation (functionSemantic3) of method members,
 * which can cause circular dependency errors when a method's body references the
 * introspecting function at compile time.
 */

struct Column { string name; }

/******** Template struct case ********/

struct Table(T)
{
    @Column("id") T id;
    @Column("data") T data;

    static string[] columnNames()
    {
        string[] result;
        static foreach (name; __traits(allMembers, Table)) {{
            static foreach (attr; __traits(getAttributes, __traits(getMember, Table, name))) {
                static if (is(typeof(attr) == Column))
                    result ~= attr.name;
            }
        }}
        return result;
    }

    // Auto-return method that references columnNames at compile time.
    // Without the fast path, __traits(getMember, Table, "save") triggers
    // functionSemantic3 (for return type inference) on save(), whose body
    // tries to CTFE columnNames() while it's already being compiled,
    // causing "circular dependency" error.
    auto save()
    {
        enum cols = columnNames();
        return cols.length;
    }
}

static assert(Table!int.columnNames() == ["id", "data"]);

/******** Mixin template case ********/

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
