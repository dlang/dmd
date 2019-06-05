// REQUIRED_ARGS: -extern-std=c++98

// This file is intended to contain all compilable traits-related tests in an
// effort to keep the number of files in the `compilable` folder to a minimum.

// https://issues.dlang.org/show_bug.cgi?id=19152

class C19152
{
    int OnExecute()
    {
        auto name = __traits(getOverloads, this, "OnExecute").stringof;
        return 0;
    }
}

static assert(is(typeof(__traits(getTargetInfo, "cppRuntimeLibrary")) == string));
version (CppRuntime_Microsoft)
{
    static assert(__traits(getTargetInfo, "cppRuntimeLibrary") == "libcmt");
}

version (D_HardFloat)
    static assert(__traits(getTargetInfo, "floatAbi") == "hard");

version (Win64)
    static assert(__traits(getTargetInfo, "objectFormat") == "coff");
version (OSX)
    static assert(__traits(getTargetInfo, "objectFormat") == "macho");
version (linux)
    static assert(__traits(getTargetInfo, "objectFormat") == "elf");

static assert(__traits(getTargetInfo, "cppStd") == 199711);

/******************************************/
// https://issues.dlang.org/show_bug.cgi?id=19942

static assert(!__traits(compiles, { a.init; }));
static assert(!__traits(compiles, { import m : a; a.init; }));
