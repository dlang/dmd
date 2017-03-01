module imports.testptrref_tmpl;

struct TStruct(T)
{
    static T tlsInstance;
    __gshared T gsharedInstance;
}

