/**
 * Module documentation.
 */
module traits_documentation;

/**
 * Function documentation.
 */
void documentedFunc() {}
/++
 + Enum documentation.
 +/
enum documentedEnum = 1;
auto documentedVar = 2; /// Some unicode: Σ σ Π π.

auto emptyVar  = 2; ///

///
auto emptyVar2  = 2;

void main()
{
    enum funcDoc = __traits(documentation, documentedFunc);
    enum enumDoc = __traits(documentation, documentedEnum);
    enum varDoc = __traits(documentation, documentedVar);
    enum modDoc = __traits(documentation, traits_documentation);

    static assert(funcDoc == " Function documentation.\n");
    static assert(enumDoc == " Enum documentation.\n");
    static assert(varDoc == "Some unicode: Σ σ Π π.\n");
    static assert(modDoc == " Module documentation.\n");

    static assert(!__traits(compiles, __traits(documentation, 3)));
    static assert(!__traits(compiles, __traits(documentation, "4")));

    static assert(__traits(documentation, emptyVar) == "\n");
    static assert(__traits(documentation, emptyVar2) == "\n");
}
