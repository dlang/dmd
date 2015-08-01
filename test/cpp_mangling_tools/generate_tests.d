//
// C++ name mangling test suite generator.
//
// This allows to test C++ name mangling correctness across platform (Linux,
// OSX, Windows) and CPU architecture (32/64 bits).
//
// This file :
// - generates C++ code.
// - compiles it with gcc or cl.exe.
// - extracts the mangled names from the compiled object file.
// - generate a D file importing the extern(C++) function and static assert
//   the name mangling is correct.
//
// Run `dmd -J. -run generate_tests.d` to create a "mangling_test_*.d" file.
// You can then copy it to the "test/compilable" folder.
//
// Warning : this tool needs a valid C++ toolchain (g++ or cl.exe) as well as
// nm or dumpbin.exe.

import std.algorithm;
import std.array : array;
import std.container;
import std.exception : enforce;
import std.range;
import std.stdio : writeln, writefln;
import std.string;
import std.system : os;

enum bits = ptrdiff_t.sizeof * 8;

struct Translation {
    string cpp, d;

    this(string line) {
        import std.format;
        formattedRead(line, "%s|%s", &cpp, &d);
        cpp = cpp.strip;
        d = d.strip;
    }
}

alias Translation[][string] Translations;

void readTranslationFile(string filename, ref Translations translations) {
    import std.path;
    auto name = baseName(filename).stripExtension();
    import std.file : readText;
    readText(filename)
        .splitLines
        .each!(a=>translations[name]~=Translation(a));
}

Translations readTranslations() {
    import std.file;
    Translations translations;
    dirEntries(".",SpanMode.shallow)
        .filter!(a=>endsWith(a.name,".cpp2d"))
        .each!(a=>readTranslationFile(a.name, translations));
    return translations;
}

struct Template {
    struct Piece {
        bool interpolate;
        string value;

        string toString() { return interpolate ? format("|%s|", value) : value; }
    }

    Piece[] pieces;
    string[] variables;
    string expansion;
    this(this) {
        pieces = pieces.dup;
        variables = variables.dup;
    }
    this(string tmpl) {
        pieces = tmpl
            .splitter('|')
            .enumerate
            .map!(a => Piece(a.index % 2, a.value))
            .array;
        variables = pieces
            .filter!(a => a.interpolate)
            .map!(a => a.value).array
            .sort.uniq.array
        ;
        auto expansions = variables.filter!(a=>canExpand(a));
        enforce(expansions.walkLength < 2, format("Only one expansion allowed %s", expansions));
        expansion = expansions.empty ? "" : expansions.front;
    }

    string interpolate(in string[string] values) in {
        auto allValues = redBlackTree(values.keys);
        assert(variables.all!(a=>a in allValues), format("Incompatible variable set : %s != %s", allValues[], variables[]) );
    } body {
        return pieces
            .map!(a => a.interpolate ? values[a.value] : a.value)
            .join;
    }

    void instantiateType(in string name, in string type) out {
        assert(expansion.empty);
    } body {
        pieces.each!((ref a) {
                if(a.interpolate && a.value == name) {
                    a.interpolate = false;
                    a.value = type;
                }
            });
        expansion = "";
        variables = variables
            .filter!((in a)=>a != name)
            .array;
    }

    string toString() {
        return format("%(%s%) [%(%s, %)] %s", pieces, variables, expansion);
    }
private:
    static bool canExpand(in string variable) {
        import std.ascii;
        return variable.length>1 && variable.all!(a=>a=='_' || isUpper(a));
    }
}

struct TestDefinition {
    string description;
    Template cppTemplate;
    Template dTemplate;
    Template dSymbolTemplate;
    string[] namespaces;
    string[string] variables;
    string cppMangledName;

    this(this) {
        variables = variables.dup;
    }

    this(in string block) {
        import std.regex : splitter, regex;
        block
            .splitter(regex("^// +", "m"))
            .map!(a=>a.strip)
            .filter!(a=>!a.empty)
            .each!(a=>ingest(a));
    }

    TestDefinition[] expandTypes(in Translations translations) {
        auto expansions = map!(a=>a.expansion)([cppTemplate, dTemplate, dSymbolTemplate]).filter!(a=>!a.empty).uniq;
        assert(expansions.walkLength <= 1, format("Only one expansion per test allowed : %s", expansions));
        if(expansions.empty)
            return [this];
        string expansion = expansions.front;
        enforce(expansion in translations, format("%s not in %s", expansion, translations.keys));
        return translations[expansion].map!(a=>instantiateType(expansion, a)).array;
    }

    void initVariables(R)(ref R numbers) if(isInputRange!R) {
        foreach(var; redBlackTree([cppTemplate.variables, dTemplate.variables, dSymbolTemplate.variables].join)) {
            variables[var] = format("%s_%d_", var, numbers.front);
            numbers.popFront;
        }
    }

    string generateCppCode() {
        scope(failure) writefln("can't format %s", this);
        auto code = cppTemplate.interpolate(variables);
        if(namespaces.length)
            code = format("%-(namespace %s {\n%) {\n %s %-(\n} // namespace %s %)", namespaces, code, namespaces.retro);
        return format("// %s\n%s", description, code);
    }

    string generateDCodeWithoutNamespace() {
        scope(failure) writefln("can't format %s", this);
        auto code = dTemplate.interpolate(variables);
        auto symbol = dSymbolTemplate.interpolate(variables);
        return `%s
%s
static assert(%s.mangleof == "%s");`.format(
    generateCppCode().splitLines.map!(a=>"// "~a).join("\n"),
    code,
    symbol,
    cppMangledName);
    }

    void findAndSetMangledName(string[] mangledNames) {
        auto found = mangledNames.filter!(a=>a.canFind(variables["foo"])).array;
        assert(found.length == 1, format("Can't find mangled name, found %s", found));
        cppMangledName = found.front;
    }
private:
    void ingest(in string tag) {
        enum Type {DESCRIPTION, CPP, D, D_SYMBOL, NAMESPACE};
        auto found = tag.findSplit(":");
        import std.ascii : isUpper;
        if(tag.empty || !tag.front.isUpper || found[1].empty)
            return;
        import std.conv : to;
        auto value = found[2].strip.to!string;
        final switch(found[0].strip.to!(Type)) {
            case Type.DESCRIPTION:
                description = value;
                break;
            case Type.CPP:
                cppTemplate = Template(value);
                break;
            case Type.D:
                dTemplate = Template(value);
                break;
            case Type.D_SYMBOL:
                dSymbolTemplate = Template(value);
                break;
            case Type.NAMESPACE:
                namespaces ~= value.split(".").array;
                break;
        }
    }

    TestDefinition instantiateType(in string name, in Translation translation) {
        TestDefinition copy = this;
        with(copy) {
            cppTemplate.instantiateType(name, translation.cpp);
            dTemplate.instantiateType(name, translation.d);
            dSymbolTemplate.instantiateType(name, translation.d);
        }
        return copy;
    }
}

string generateTemporaryFileName(string content, string ext) {
    import std.file : tempDir;
    import std.path : buildPath;
    import std.digest.md;
    return buildPath(tempDir(), "tmp_" ~ toHexString(md5Of(content))) ~ ext;
}

string execute(string[] args)
{
    import std.process : execute;
    auto result = execute(args);
    enforce(result.status == 0, format("execution failed %(%s %) : %s\n", args, result.output));
    return result.output;
}

void cleanupFile(in string filename) {
    import std.file : remove, exists;
    if(exists(filename))
        remove(filename);
}

string[] compileCppAndGetSymbols(in string content)
{
    const cpp_filename = generateTemporaryFileName(content, ".cc");
    import std.file : write;
    write(cpp_filename, content);
    scope(exit) cleanupFile(cpp_filename);
    import std.path;
    const obj_filename = cpp_filename.setExtension(".o");
    scope(exit) cleanupFile(obj_filename);
    {
        scope(failure) writeln("error while compiling cpp file with content :\n", content);
        version(Windows) {
            execute(["cl", cpp_filename, "/c", "/Fo" ~ obj_filename]);
        } else {
            execute(["g++", "-std=c++11", "-c", "-o", obj_filename, cpp_filename]);
        }
    }
    version(Windows) {
        return execute(["dumpbin", "/SYMBOLS", obj_filename])
        .lineSplitter
        .map!(a => a.findSplitBefore("?")[1].findSplitBefore(" ")[0])
        .array;
    } else {
        return execute(["nm", obj_filename, "-f", "posix"])
        .lineSplitter
        .map!(a => a.findSplitBefore(" ")[0])
        .array;
    }
}

TestDefinition[] getAllTests(in Translations translations) {
    import std.regex : splitter, regex;
    // Split config file into blocks.
    auto blocks = import("name_mangling.tests")
        .splitter(regex("^// *-+$", "m"))
        .map!(a=>a.strip);
    // Instanciate all test configurations and expand TYPES variables.
    auto allTests = blocks
        .map!(a=>TestDefinition(a).expandTypes(translations))
        .joiner
        .array;
    // Generate names for variables.
    auto numbers = iota(10000);
    allTests.each!((ref a)=>a.initVariables(numbers));
    return allTests;
}

string generateCppCode(ref TestDefinition[] allTests) {
    return format(`#include <cstddef>
struct S {};

%-(%s

%)`, allTests.map!(a=>a.generateCppCode()));
}

string generateDCode(ref TestDefinition[] allTests) {
    // D disallow multiple identical extern C++ namespace so tests have to be
    // grouped per extern namespaces.
    auto testsGroupedByNamespace = allTests
        .sort!((a,b) => a.namespaces < b.namespaces, SwapStrategy.stable)
        .groupBy;
    auto formatNamespaceTests = (TestDefinition[] tests) {
        assert(!tests.empty);
        auto namespaces = tests.front.namespaces;
        auto externDecl = namespaces.empty ?
            `extern(C++)` :
            `extern(C++, %s)`.format(namespaces.join("."));
        return `
%s {

%-(%s

%)

}`.format(externDecl, tests.map!(a=>a.generateDCodeWithoutNamespace()));
    };
    return format(`// DO NOT EDIT MANUALLY
// This code is autogenerated.
// Have a look at test/cpp_mangling_tools/README.md for more informations.

import core.stdc.config;

version(%s):
static if(ptrdiff_t.sizeof == %d): // Only for %d bits systems

struct S {}
%-(%s

%)`, os, ptrdiff_t.sizeof, bits, testsGroupedByNamespace.map!(a=>formatNamespaceTests(a.array))
);
}

void main() {
    auto translations = readTranslations();
    auto allTests = getAllTests(translations);
    // Generate, compile cpp code and get symbols.
    auto allSymbols = compileCppAndGetSymbols(generateCppCode(allTests));
    // Set back mangled name in the test.
    allTests.each!((ref a)=>a.findAndSetMangledName(allSymbols));
    // Generate D code.
    auto dCode = generateDCode(allTests);
    import std.file : write;
    auto filename = format("cpp_mangling_test_%s_%d.d", os, bits);
    write(filename, dCode);
    writefln("Wrote '%s'", filename);
}
