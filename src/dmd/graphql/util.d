module dmd.graphql.util;

import std.stdio : write, writeln, writefln;

import dmd.graphql.core;

class DumpDataHandler : IQueryDataHandler
{
    import std.array : Appender;
    Appender!(char[]) json;
    Appender!(string[]) errors;
    void dump()
    {
        writeln(json.data);
    }

    void errorSelectOnValue(const(QuerySelectionSet) set, TypeKind kind)
    {
        import std.format : format;
        errors.put(format("cannot select fields from type %s", kind));
    }

    void objectStart() { json.put("{"); }
    void objectEnd() { json.put("}"); }
    void string_(string str)
    {
        json.put("\"");
        json.put(str); // todo: escape it
        json.put("\"");
    }
    void boolean(bool b) { json.put(b ? "true" : "false"); }
}

/+
int main(string[] args)
{
    auto compilerInfoType = graphql.Type([
        graphql.Field("binary", graphql.Type.string_),
        graphql.Field("version", graphql.Type.string_),
        graphql.Field("supportsIncludeImports", graphql.Type.boolean)]);
    

    auto rootType = graphql.Type([
        graphql.Field("compilerInfo", compilerInfoType)
        ]);

    //
    // Create Fake Data
    //
    auto data = QueryData(QueryDataObject([
        QueryDataObject.Field("compilerInfo", QueryData(QueryDataObject([
            QueryDataObject.Field("binary", QueryData("dmd")),
            QueryDataObject.Field("version", QueryData("1.0")),
            QueryDataObject.Field("supportsIncludeImports", QueryData(true)),
        ]))),
    ]));


    auto query = makeQuery(QueryField(null, "compilerInfo"));
    auto dumpHandler = new DumpDataHandler();
    rootType.query(query, data, dumpHandler);
    dumpHandler.dump();

    return 0;
}
+/