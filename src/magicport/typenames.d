
bool[string] basicTypes;
bool[string] structTypes;
bool[string] classTypes;
bool[string] rootClasses;
string[][] overridenFuncs;
string[] nonFinalClasses;

bool lookup(bool[string] aa, string n)
{
    auto p = n in aa;
    if (p) *p = true;
    return p !is null;
}

auto dropdefaultctor = ["Loc", "Token", "HdrGenState", "CtfeStack", "InterState", "BaseClass", "Mem", "StringValue", "OutBuffer", "Scope", "DocComment", "PrefixAttributes", "Prot", "UnionExp"];
