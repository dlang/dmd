// EXECUTE_ARGS: --check

//
// Automatic C++ name mangling checker.
// This allows to test C++ name mangling correctness across platform (Linux,
// OSX, Windows) and machine architecture (32/64 bits).
//
// This file :
// - generates C++ code.
// - compiles it with gcc or cl.exe.
// - extracts the mangled names from the compiled object file.
// - generate a D file importing the extern(C++) function and static assert
//   the name mangling is correct.
// - executes this D file and make sure it runs correctly.
//
// Run `dmd -run name_mangling_checker.d` to output the generated D code.
// Run `dmd -run name_mangling_checker.d --check` to run the check.
//
// Warning : this test needs a valid C++ toolchain (g++ or cl.exe) as well as
// nm or dumpbin.exe.

import std.stdio : writeln;
import std.format;
import std.algorithm.iteration;
import std.algorithm.searching;
import std.range;
import std.typecons : Flag;
import std.string : lineSplitter;
import std.exception : enforce;
import std.file : remove, write;

struct Translation
{
    string cpp;
    string d;
}

struct ManglingTest
{
    string dSymbol;
    string cpp;
    string d;
    immutable(string)[] namespaces;
    string cppFooName;
    string cppMangling;
}

immutable dFileTemplate = `import core.stdc.config;

struct S{}
struct Struct(T){}

%-(%s

%)
`;

immutable cppFileTemplate = `#include <cstddef>

struct S{};
template<typename T> struct Struct{};

%-(%s

%)
`;

immutable string[] emptyNamespace = [];
immutable string[] singleNamespace = ["single"];
immutable string[] nestedNamespace = ["ns0", "ns1", "ns2"];
immutable string[] stdNamespace = ["std"];

// interpolation functions
static auto Function = iota(int.max).map!(a => format("foo_%03d_", a));
static auto Struct   = iota(int.max).map!(a => format("Struct_%03d_", a));
static auto Template = iota(int.max).map!(a => format("Template_%03d_", a));

string next(R)(ref R range)
{
    string output = range.front;
    range.popFront();
    return output;
}

string getValue(string token, ref string[string] context)
{
    assert(!token.empty);
    auto pointer = token in context;
    if (pointer is null) {
        switch(token[0]) {
            case 'F': return context[token] = next(Function);
            case 'S': return context[token] = next(Struct);
            case 'T': return context[token] = next(Template);
            default: assert(false, "token must start by F, S, or T.");
        }
    }
    return *pointer;
}

string interpolate(string templateString, ref string[string] context)
{
    return templateString
        .splitter('|')
        .enumerate
        .map!(a => (a.index % 2) ? getValue(a.value, context) : a.value)
        .join();
}

ManglingTest interpolate(in ManglingTest test, ref string[string] context)
{
    with(test) return ManglingTest(
        interpolate(dSymbol, context),
        interpolate(cpp, context),
        interpolate(d, context),
        namespaces,
        interpolate("|F|", context),
    );
}

ManglingTest interpolate(in ManglingTest test, in Translation translation)
{
    string[string] context = [
        "cpp": translation.cpp,
        "d": translation.d,
    ];
    return interpolate(test, context);
}

ManglingTest interpolate(in ManglingTest test)
{
    string[string] context;
    return interpolate(test, context);
}

// The following function will generate the c++ and d test source code.

auto getFreeFunctionTests(immutable(string[]) namespaces)
{
    immutable Translation[] translations = [
        // single basic type
        {"",                        ""},
        {"bool",                    "bool"},
        {"signed char",             "byte"},
        {"unsigned char",           "ubyte"},
        {"char",                    "char"},
        {"wchar_t",                 "dchar"},
        // {"char16_t",                "wchar"}, // doesn't work
        // {"char32_t",                "dchar"}, // doesn't work
        {"short",                   "short"},
        {"unsigned short",          "ushort"},
        {"int",                     "int"},
        {"unsigned int",            "uint"},
        {"long",                    "core.stdc.config.c_long"},
        {"unsigned long",           "core.stdc.config.c_ulong"},
        {"float",                   "float"},
        {"double",                  "double"},
        {"long double",             "real"},
        {"double _Complex",         "cdouble"},
        {"long double _Complex",    "creal"},
        {"size_t",                  "size_t"},
        {"ptrdiff_t",               "ptrdiff_t"},
        // single qualified basic type
        {"int*",                    "int*"},
        {"const int",               "const int"},
        {"const int*",              "const(int)*"},
        {"const int* const",        "const(int*)"},
        {"int&",                    "ref int"},
        {"const int&",              "const ref int"},
        // single qualified type
        {"S",                       "S"},
        {"S*",                      "S*"},
        {"const S",                 "const S"},
        {"const S*",                "const(S)*"},
        {"const S* const",          "const(S*)"},
        {"S&",                      "ref S"},
        {"const S&",                "const ref S"},
        // single function type
        {"void*(*)()",              "void* function()"},
        {"int(*)(int)",             "int function(int)"},
        // function type and substitution
        {"void*(*)(), void*",       "void* function(), void*"},
        {"void(*)(void*), void*",   "void function(void*), void*"},
        {"void*(*)(void**), void*", "void* function(void**), void*"},
        {"void*(*)(void**), void**","void* function(void**), void**"},
        {"void*(*)(void*), void*(*)(void*)",  "void* function(void*), void* function(void*)"},
    ];
    immutable testTemplate = ManglingTest(
        "|F|",
        "void |F|(|cpp|) {}",
        "void |F|(|d| /* |cpp| */);",
        namespaces,
    );
    return translations.map!(a => interpolate(testTemplate, a));
}

ManglingTest getStructMemberTest(Flag!"Const" isConst, immutable(string[]) namespaces)
{
    string[string] context = ["const" : isConst ? "const" : "" ];
    immutable testTemplate = ManglingTest(
        "|S|.|F|",
        "struct |S| { void |F|() |const|; }; void |S|::|F|() |const| {}",
        "struct |S| { void |F|() |const|; }",
        namespaces,
    );
    return interpolate(testTemplate, context);
}

ManglingTest[] getStructMemberTest(immutable(string[]) namespaces)
{
    return [
        getStructMemberTest(Flag!"Const".no, namespaces),
        getStructMemberTest(Flag!"Const".yes, namespaces)
    ];
}

auto getTemplateTests(immutable(string[]) namespaces)
{
    immutable ManglingTest[] templates = [
        {
            "|F|!int",
            "template<typename T> void |F|(){}; template void |F|<int>();",
            "void |F|(T)();", namespaces,
        },
        {
            "|F|!(Struct!(Struct!(Struct!int)))",
            "template<typename T> void |F|(){}; template void |F|<Struct<Struct<Struct<int> > > >();",
            "void |F|(T)();", namespaces,
        },
        {
            "|F|!int",
            "template<typename T> void |F|(T){}; template void |F|<int>(int);",
            "void |F|(T)(T);", namespaces,
        },
        {
            "|F|!(int,char,uint)",
            "template<typename A, typename B, typename C> void |F|(A,B&,C){}; template void |F|<int,char,unsigned>(int,char&,unsigned);",
            "void |F|(A,B,C)(A,ref B,C);", namespaces,
        },
    ];
    return templates.map!(a => interpolate(a));
}

auto getNestedSymbolTests()
{
    immutable ManglingTest[] templates = [
        {
            "|F|",
            "struct |S| {};void |F|(|S|){}",
            "struct |S| {};void |F|(|S|){}",
            nestedNamespace,
        },
        {
            "|S|!int.|F|!char",
            "template<typename A> struct |S| {template<typename B> B* |F|(const B**) const;};\ntemplate<> template<> char* |S|<int>::|F|<char>(const char**) const { return nullptr; };",
            "struct |S|(A) { B* |F|(B)(const(B)**) const; }",
            nestedNamespace,
        },
        {
            "|S1|!int.|F|!|S2|",
            "struct |S2| {};template<typename A> struct |S1| {template<typename B> B* |F|(const B**) const;};\ntemplate<> template<> |S2|* |S1|<int>::|F|<|S2|>(const |S2|**) const { return nullptr; };",
            "struct |S2| {};struct |S1|(A) { B* |F|(B)(const(B)**) const; }",
            nestedNamespace,
        },
    ];
    return templates.map!(a => interpolate(a));
}

// Transformations

ManglingTest putCppInNamespace(ManglingTest test)
{
    with(test) if(namespaces.length)
        cpp = format("%-(namespace %s {\n%) {\n %s %-(\n} // namespace %s %)", namespaces, cpp, namespaces.retro);
    return test;
}

string generateTemporaryFilename(string content)
{
    import std.file : tempDir;
    import std.path : buildPath;
    import std.digest.md;
    return buildPath(tempDir(), "tmp_" ~ toHexString(md5Of(content)));
}

string generateTemporaryFile(string content, string ext)
{
    string filename = generateTemporaryFilename(content);
    filename ~= ext;
    write(filename, content);
    return filename;
}

string execute(string[] args)
{
    import std.process : execute;
    auto result = execute(args);
    enforce(result.status == 0, format("execution failed %(%s %) : %s\n", args, result.output));
    return result.output;
}

auto compileCppAndGetSymbols(in string content)
{
    const cpp_filename = generateTemporaryFile(content, ".cc");
    scope(exit) remove(cpp_filename);
    import std.path;
    const obj_filename = cpp_filename.setExtension(".o");
    scope(exit) remove(obj_filename);
    {
        scope(failure) writeln("error while compiling cpp file with content :\n", content);
        version(Windows) {
        	execute(["cl", cpp_filename, "/c", "/Fo" ~ obj_filename]);
        } else {
        	execute(["g++", "-std=c++11", "-c", cpp_filename, "-o", obj_filename]);
        }
    }
    version(Windows) {
        return execute(["dumpbin", "/SYMBOLS", obj_filename])
        .lineSplitter
        .map!(a => a.findSplitBefore("?")[1].findSplitBefore(" ")[0]);
    } else {
        return execute(["nm", obj_filename, "-f", "posix"])
        .lineSplitter
        .map!(a => a.findSplitBefore(" ")[0]);
    }
}

ManglingTest byNamespaceDCode(ManglingTests)(ManglingTests tests)
{
    assert(!tests.empty);
    auto first = tests.front;
    auto allDStatements = tests.map!(a => a.d);
    with(first) {
        auto dNamespace = namespaces.length
            ? format("extern(C++, %s) {\n%-(%s\n\n%)\n\n}", namespaces.join('.'), allDStatements)
            : format("extern(C++) {\n%-(%s\n\n%)\n\n}", allDStatements);
        d = dNamespace;
        return first;
    }
}

ManglingTest addAsserts(ManglingTest test)
{
    with(test) d ~= format("\nstatic assert(%s.mangleof == \"%s\");", dSymbol, cppMangling);
    return test;
}

ManglingTest addMangledName(in string[] mangledCppSymbols, ManglingTest test)
{
    auto found = mangledCppSymbols.find!(a => canFind(a, test.cppFooName));
    enforce(!found.empty, format("Can't find mangled name for %s", test));
    test.cppMangling = found.front;
    return test;
}

void checkCompile(in string dCheckCode)
{
    const d_filename = generateTemporaryFile(dCheckCode, ".d");
    scope(exit) remove(d_filename);
    execute(["dmd", "-main", "-run", d_filename]);
}

void main(string[] args)
{
    import std.getopt;
    bool check;
    getopt(args, "check", &check);
    import std.array : array;
    auto tests = chain(
        getFreeFunctionTests(emptyNamespace),
        getFreeFunctionTests(singleNamespace),
        getFreeFunctionTests(nestedNamespace),
        getStructMemberTest(emptyNamespace),
        getStructMemberTest(singleNamespace),
//         getStructMemberTest(stdNamespace),
//         getTemplateTests(emptyNamespace),
//         getTemplateTests(singleNamespace),
//         getNestedSymbolTests(),
    );
    auto testsWithCppInNamespace = tests.map!putCppInNamespace.array;
    auto allCppSnippets = testsWithCppInNamespace.map!(a => a.cpp);
    immutable cppFileContent = format(cppFileTemplate, allCppSnippets);
    string[] mangledCppSymbols = compileCppAndGetSymbols(cppFileContent).array;
    auto testsWithMangledName = testsWithCppInNamespace.map!(a => addMangledName(mangledCppSymbols, a));
    auto testsWithDAsserts = testsWithMangledName.map!addAsserts;
    import std.algorithm.sorting;
    auto testsWithDNamespace = testsWithDAsserts
        .array
        .sort!((a,b) => a.namespaces < b.namespaces, SwapStrategy.stable)
        .groupBy
        .map!byNamespaceDCode;
    auto allDSnippets = testsWithDNamespace.map!(a => a.d);
    immutable dCheckCode = format(dFileTemplate, allDSnippets);
    if(check)
    {
        checkCompile(dCheckCode);
    }
    else
    {
        writeln(dCheckCode);
    }
}
