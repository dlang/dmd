module dmd.graphql.core;

enum TypeKind
{
    boolean,
    string_,
    object_,
}

struct QueryDataObject
{
    struct Field
    {
        string name;
        QueryData value;
    }
    Field[] fields;
}
struct QueryData
{
    union
    {
        QueryDataObject object_;
        string str;
        bool bool_;
    }
    TypeKind kind;
    this(QueryDataObject object_)
    {
        this.object_ = object_;
        this.kind = TypeKind.object_;
    }
    this(string str) { this.str = str; this.kind = TypeKind.string_; }
    this(bool bool_) { this.bool_ = bool_; this.kind = TypeKind.boolean; }
    QueryDataObject asObject()
    {
        assert(kind == TypeKind.object_);
        return object_;
    }
}


interface IQueryDataHandler
{
    void errorSelectOnValue(const(QuerySelectionSet), TypeKind);

    void objectStart();
    void objectEnd();
    void string_(string str);
    void boolean(bool b);
}


//
// NOTE: the following data structures are generated from
//       the grammar specification of a graphql query
struct QueryValue
{
}
struct QueryArgument
{
    string name;
    QueryValue value;
}
struct QueryDirective
{
    string name;
    QueryArgument[] arguments;
}
struct QueryField
{
    string alias_;
    string name;
    QueryArgument[] arguments;
    QueryDirective[] directives;
    QuerySelectionSet subSelectionSet;
    void toString(scope void delegate(const(char)[]) sink) const
    {
        if (alias_)
        {
            sink(alias_);
            sink(": ");
        }
        sink(name);
        if (arguments)
        {
            assert(0, "not implemented");
        }
        if (subSelectionSet.selections !is null)
        {
            assert(0, "not implemented");
        }
    }
}

struct QuerySelection
{
    enum Kind { field, fragmentSpread, inlineFragment }
    union
    {
        QueryField field;
    }
    Kind kind;
    this(QueryField field)
    {
        this.field = field;
        this.kind = Kind.field;
    }
    void toString(scope void delegate(const(char)[]) sink) const
    {
        final switch(kind)
        {
            case Kind.field: field.toString(sink); return;
            case Kind.fragmentSpread: assert(0, "not implemented"); return;
            case Kind.inlineFragment: assert(0, "not implemented"); return;
        }
    }
}

struct QuerySelectionSet
{
    @property static auto nullValue() { return QuerySelectionSet(); }

    QuerySelection[] selections;
    void toString(scope void delegate(const(char)[]) sink) const
    {
        sink("{");
        foreach (ref selection; selections)
        {
            selection.toString(sink);
        }
        sink("}");
    }
}
void query(T)(const(QuerySelectionSet) selectionSet, IQueryDataHandler handler, T value)
{
    static if(is(T == string))
    {
        if (selectionSet.selections.length > 0)
            handler.errorSelectOnValue(selectionSet, TypeKind.string_);
        else
            handler.string_(value);
    }
    else static assert(0, "not implemented");
}
unittest
{
    import dmd.graphql.util : DumpDataHandler;
    {
        scope handler = new DumpDataHandler();
        query(makeQuery(), handler, "hello");
        assert(handler.json.data == `"hello"`);
    }
    {
        scope handler = new DumpDataHandler();
        query(makeQuery(QueryField(null, "a")), handler, "hello");
        assert(handler.errors.data.length == 1);
    }
    /*
    {
        scope handler = new DumpDataHandler();
        query(makeQuery(), handler, ["a":0,"b":"foo"]);
        assert(handler.errors.data.length == 1);
    }
    */
}


auto makeQuery(T...)(T args)
{
    auto selections = new QuerySelection[args.length];
    foreach (i, arg; args)
    {
        static if (is(typeof(arg) : QueryField))
        {
            selections[i] = QuerySelection(arg);
        }
        else static assert(0);
    }
    return QuerySelectionSet(selections);
}

struct DefaultPolicy { }
alias graphql = graphqlTemplate!DefaultPolicy;

enum TypeFlags
{
    none     = 0x00,
    optional = 0x01,
    array    = 0x02,
   
    optionalArray = optional | array,
}

template graphqlTemplate(Policy)
{
    struct Type
    {
        union
        {
            Field[] fields = void;
        }
        TypeKind kind;
        TypeFlags flags;
        this(TypeFlags flags, Field[] fields)
        {
            this.kind = TypeKind.object_;
            this.flags = flags;
            this.fields = fields;
        }
        this(TypeFlags flags, immutable(Field)[] fields) immutable
        {
            this.kind = TypeKind.object_;
            this.flags = flags;
            this.fields = fields;
        }

        private this(TypeKind kind, TypeFlags flags)
        {
            this.kind = kind;
            this.flags = flags;
        }
        static auto string_(TypeFlags flags = TypeFlags.none) { return Type(TypeKind.string_, flags); }
        static auto boolean(TypeFlags flags = TypeFlags.none) { return Type(TypeKind.boolean, flags); }

        void query(const(QuerySelectionSet) query, QueryData data, IQueryDataHandler handler)
        {
            import std.stdio : writefln;
            writefln("query '%s'", query);
            if (query.selections.length == 0)
            {
                final switch (kind)
                {
                case TypeKind.boolean:
                    assert(data.kind == TypeKind.boolean);
                    handler.boolean(data.bool_);
                    break;
                case TypeKind.string_:
                    assert(data.kind == TypeKind.string_);
                    handler.string_(data.str);
                    break;
                case TypeKind.object_:
                    {
                        handler.objectStart();
                        scope(exit) handler.objectEnd();
                        foreach (ref field; fields)
                        {
                            field.type.query(QuerySelectionSet.nullValue,
                                field.resolver.resolveField(data.asObject, &field), handler);
                        }
                    }
                    break;
                }
                return;
            }
        
            final switch (kind)
            {
                case TypeKind.boolean:
                    assert(0, "not implemented");
                case TypeKind.string_:
                    assert(0, "not implemented");
                case TypeKind.object_:
                    {
                        handler.objectStart();
                        scope(exit) handler.objectEnd();
                        foreach (selection; query.selections)
                        {
                            final switch(selection.kind)
                            {
                            case QuerySelection.Kind.field:
                                auto field = getObjectField(selection.field.name);
                                if (field is null)
                                {
                                    writefln("Error: this type does not contain a field named '%s'", selection.field.name);
                                    return;
                                }
                                field.type.query(selection.field.subSelectionSet,
                                    getObjectFieldValue(data.asObject, field), handler);
                                break;
                            case QuerySelection.Kind.fragmentSpread: assert(0, "not implemented"); return;
                            case QuerySelection.Kind.inlineFragment: assert(0, "not implemented"); return;
                            }
                        }
                    }
                    break;
            }
            
        }

        private Field* getObjectField(string name)
        {
            foreach(ref field; fields)
            {
                if (name == field.name)
                    return &field;
            }
            return null;
        }
        private QueryData getObjectFieldValue(QueryDataObject obj, Field* field)
        {
            foreach(ref objField; obj.fields)
            {
                if (objField.name == field.name)
                {
                    return objField.value;
                }
            }
            assert(0, "object missing field " ~ field.name);
        }
    }
    struct Field
    {
        string name;
        Type type;
        Resolver resolver;
    }
    struct Resolver
    {
    /*
        QueryData resolve(QueryData data, Type type)
        {
            assert(0, "not implemented");
        }
        */
        QueryData resolveField(QueryDataObject obj, Field* field)
        {
            foreach(ref objField; obj.fields)
            {
                if (objField.name == field.name)
                {
                    return objField.value;
                }
            }
            assert(0, "field missing");
        }
        //QueryData resolveField(QueryData 
    }
}

