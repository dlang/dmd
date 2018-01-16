/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This modules defines the help texts for the CLI options offered by DMD.
 * This file is not shared with other compilers which use the DMD front-end.
 * However, this file will be used to generate the
 * $(LINK2 https://dlang.org/dmd-linux.html, online documentation) and MAN pages.
 *
 * Copyright:   Copyright (c) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cli.d, _cli.d)
 * Documentation:  https://dlang.org/phobos/dmd_cli.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cli.d
 */
module dmd.cli;

/// Bit decoding of the TargetOS
enum TargetOS
{
    all = int.max,
    linux = 1,
    windows = 2,
    macOS = 4,
    freeBSD = 8,
    solaris = 16,
}

// Detect the current TargetOS
version (linux)
{
    private enum targetOS = TargetOS.linux;
}
else version(Windows)
{
    private enum targetOS = TargetOS.windows;
}
else version(OSX)
{
    private enum targetOS = TargetOS.macOS;
}
else version(FreeBSD)
{
    private enum targetOS = TargetOS.freeBSD;
}
else version(Solaris)
{
    private enum targetOS = TargetOS.solaris;
}
else
{
    private enum targetOS = TarggetOS.all;
}

/**
Checks whether `os` is the current $(LREF TargetOS).
For `TargetOS.all` it will always return true.

Params:
    os = $(LREF TargetOS) to check

Returns: true iff `os` contains the current targetOS.
*/
bool isCurrentTargetOS(TargetOS os)
{
    return (os & targetOS) > 0;
}

/**
Contains all available CLI $(LREF Option)s.

See_Also: $(LREF Option)
*/
struct Usage
{
    /// Representation of a CLI `Option`
    struct Option
    {
        string flag; /// The CLI flag without leading `-`, e.g. `color`
        string helpText; /// A detailed description of the flag
        TargetOS os = TargetOS.all; /// For which `TargetOS` the flags are applicable
    }

    /// Returns all available CLI options
    static immutable options = [
        Option("allinst",
            "generate code for all template instantiations"
        ),
        Option("betterC",
            "omit generating some runtime information and helper functions"
        ),
        Option("boundscheck=[on|safeonly|off]",
            "bounds checks on, in @safe only, or off"
        ),
        Option("c",
            "do not link"
        ),
        Option("color",
            "turn colored console output on"
        ),
        Option("color=[on|off]",
            "force colored console output on or off"
        ),
        Option("conf=<filename>",
            "use config file at filename"
        ),
        Option("cov",
            "do code coverage analysis"
        ),
        Option("cov=<nnn>",
            "require at least nnn% code coverage"
        ),
        Option("D",
            "generate documentation"
        ),
        Option("Dd<directory>",
            "write documentation file to directory"
        ),
        Option("Df<filename>",
            "write documentation file to filename"
        ),
        Option("d",
            "silently allow deprecated features"
        ),
        Option("dw",
            "show use of deprecated features as warnings (default)"
        ),
        Option("de",
            "show use of deprecated features as errors (halt compilation)"
        ),
        Option("debug",
            "compile in debug code"
        ),
        Option("debug=<level>",
            "compile in debug code <= level"
        ),
        Option("debug=<ident>",
            "compile in debug code identified by ident"
        ),
        Option("debuglib=<name>",
            "set symbolic debug library to name"
        ),
        Option("defaultlib=<name>",
            "set default library to name"
        ),
        Option("deps",
            "print module dependencies (imports/file/version/debug/lib)"
        ),
        Option("deps=<filename>",
            "write module dependencies to filename (only imports)"
        ),
        Option("fPIC",
            "generate position independent code",
            TargetOS.linux
        ),
        Option("dip25",
            "implement http://wiki.dlang.org/DIP25"
        ),
        Option("dip1000",
            "implement https://github.com/dlang/DIPs/blob/master/DIPs/DIP1000.md"
        ),
        Option("dip1008",
            "implement https://github.com/dlang/DIPs/blob/master/DIPs/DIP1008.md"
        ),
        Option("g",
            "add symbolic debug info"
        ),
        Option("gf",
            "emit debug info for all referenced types"
        ),
        Option("gs",
            "always emit stack frame"
        ),
        Option("gx",
            "add stack stomp code"
        ),
        Option("H",
            "generate 'header' file"
        ),
        Option("Hd=<directory>",
            "write 'header' file to directory"
        ),
        Option("Hf=<filename>",
            "write 'header' file to filename"
        ),
        Option("-help",
            "print help and exit"
        ),
        Option("I=<directory>",
            "look for imports also in directory"
        ),
        Option("i",
            "same as -i=-std,-core,-etc,-object"
        ),
        Option("i=[-]<pkg>,...",
            "include/exclude imported modules whose name matches one of <pkg>"
        ),
        Option("ignore",
            "ignore unsupported pragmas"
        ),
        Option("inline",
            "do function inlining"
        ),
        Option("J=<directory>",
            "look for string imports also in directory"
        ),
        Option("L=<linkerflag>",
            "pass linkerflag to link"
        ),
        Option("lib",
            "generate library rather than object files"
        ),
        Option("m32",
            "generate 32 bit code"
        ),
        Option("m32mscoff",
            "generate 32 bit code and write MS-COFF object files",
            TargetOS.windows
        ),
        Option("m64",
            "generate 64 bit code"
        ),
        Option("main",
            "add default main() (e.g. for unittesting)"
        ),
        Option("man",
            "open web browser on manual page"
        ),
        Option("map",
            "generate linker .map file"
        ),
        Option("mcpu=<id>",
            "generate instructions for architecture identified by 'id'"
        ),
        Option("mcpu=?",
            "list all architecture options"
        ),
        Option("mscrtlib=<name>",
            "MS C runtime library to reference from main/WinMain/DllMain",
            TargetOS.windows
        ),
        Option("mv=<package.module>=<filespec>",
            "use <filespec> as source file for <package.module>"
        ),
        Option("noboundscheck",
            "no array bounds checking (deprecated, use -boundscheck=off)"
        ),
        Option("O",
            "optimize"
        ),
        Option("o-",
            "do not write object file"
        ),
        Option("od=<directory>",
            "write object & library files to directory"
        ),
        Option("of=<filename>",
            "name output file to filename"
        ),
        Option("op",
            "preserve source path for output files"
        ),
        Option("profile",
            "profile runtime performance of generated code"
        ),
        Option("profile=gc",
            "profile runtime allocations"
        ),
        Option("release",
            "compile release version"
        ),
        Option("shared",
            "generate shared library (DLL)"
        ),
        Option("transition=<id>",
            "help with language change identified by 'id'"
        ),
        Option("transition=?",
            "list all language changes"
        ),
        Option("unittest",
            "compile in unit tests"
        ),
        Option("v",
            "verbose"
        ),
        Option("vcolumns",
            "print character (column) numbers in diagnostics"
        ),
        Option("verrors=<num>",
            "limit the number of error messages (0 means unlimited)"
        ),
        Option("verrors=spec",
            "show errors from speculative compiles such as __traits(compiles,...)"
        ),
        Option("vgc",
            "list all gc allocations including hidden ones"
        ),
        Option("vtls",
            "list all variables going into thread local storage"
        ),
        Option("-version",
            "print compiler version and exit"
        ),
        Option("version=<level>",
            "compile in version code >= level"
        ),
        Option("version=<ident>",
            "compile in version code identified by ident"
        ),
        Option("w",
            "warnings as errors (compilation will halt)"
        ),
        Option("wi",
            "warnings as messages (compilation will continue)"
        ),
        Option("X",
            "generate JSON file"
        ),
        Option("Xf=<filename>",
            "write JSON file to filename"
        ),
    ];

    /// Representation of a CLI transition
    struct Transition
    {
        string bugzillaNumber; /// bugzilla issue number (if existent)
        string name; /// name of the transition
        string paramName; // internal transition parameter name
        string helpText; // detailed description of the transition
    }

    /// Returns all available transitions
    static immutable transitions = [
        Transition("3449", "field", "vfield",
            "list all non-mutable fields which occupy an object instance"),
        Transition("10378", "import", "bug10378",
            "revert to single phase name lookup"),
        Transition(null, "checkimports", "check10378",
            "give deprecation messages about 10378 anomalies"),
        Transition("14488", "complex", "vcomplex",
            "give deprecation messages about all usages of complex or imaginary types"),
        Transition("16997", "intpromote", "fix16997",
            "fix integral promotions for unary + - ~ operators"),
        Transition(null, "tls", "vtls",
            "list all variables going into thread local storage"),
    ];
}

/**
Formats the `Options` for CLI printing.
*/
struct CLIUsage
{
    /**
    Returns a string of all available CLI options for the current targetOS.
    Options are separated by newlines.
    */
    static string usage()
    {
        enum maxFlagLength = 18;
        enum s = () {
            string buf;
            foreach (option; Usage.options)
            {
                if (option.os.isCurrentTargetOS)
                {
                    buf ~= "  -";
                    buf ~= option.flag;
                    // emulate current behavior of DMD
                    if (option.flag == "defaultlib=<name>")
                    {
                            buf ~= "\n                    ";
                    }
                    else if (option.flag.length <= maxFlagLength)
                    {
                        foreach (i; 0 .. maxFlagLength - option.flag.length - 1)
                            buf ~= " ";
                    }
                    else
                    {
                            buf ~= "  ";
                    }
                    buf ~= option.helpText;
                    buf ~= "\n";
                }
            }
            return buf;
        }();
        return s;
    }

    /// CPU architectures supported -mcpu=id
    static string mcpu()
    {
        return "
CPU architectures supported by -mcpu=id:
  =?             list information on all architecture choices
  =baseline      use default architecture as determined by target
  =avx           use AVX 1 instructions
  =avx2          use AVX 2 instructions
  =native        use CPU architecture that this compiler is running on
";
    }

    /// Language changes listed by -transition=id
    static string transitionUsage()
    {
        enum maxFlagLength = 20;
        enum s = () {
            auto buf = "Language changes listed by -transition=id:
";
            auto allTransitions = [Usage.Transition(null, "all", null,
                "list information on all language changes")] ~ Usage.transitions;
            foreach (t; allTransitions)
            {
                buf ~= "  =";
                buf ~= t.name;
                auto lineLength = 3 + t.name.length;
                if (t.bugzillaNumber !is null)
                {
                    buf ~= "," ~ t.bugzillaNumber;
                    lineLength += t.bugzillaNumber.length + 1;
                }
                foreach (i; 0 .. maxFlagLength - lineLength)
                    buf ~= " ";
                buf ~= t.helpText;
                buf ~= "\n";
            }
            return buf;
        }();
        return s;
    }
}
