/// Wrapper which accepts DMC command-line syntax
/// and passes the transformed options to a MSVC cl.exe.
module msvc_dmc;

import std.algorithm.searching;
import std.array;
import std.file;
import std.path;
import std.process;
import std.stdio;

int main(string[] args)
{
    import std.conv: to;
    import std.format: format;

    enum defaultVSVersion = "10.0";
    auto cl = environment.get("MSVC_CC",
        environment.get("VCINSTALLDIR",
                        `\Program Files (x86)\Microsoft Visual Studio %s\VC\`.format(defaultVSVersion))
            .buildPath("bin", "amd64", "cl.exe"));
    string[] newArgs = [cl];
    newArgs ~= "/nologo";
    newArgs ~= `/Ivcbuild`;
    newArgs ~= `/Idmd\root`;
    newArgs ~= `/FIwarnings.h`;

    if (environment.get("VisualStudioVersion", defaultVSVersion).to!double >= 14.0)
    {
        // either this or /EHsc due to 'noexcept' in system headers
        newArgs ~= `/D_HAS_EXCEPTIONS=0`;
        // disable narrowing conversion warnings
        newArgs ~= `/Wv:18`;
    }
    bool compilingOnly;

    foreach (arg; args[1..$])
    {
        switch (arg)
        {
            case "-Ae": // "enable exception handling"
                newArgs ~= "/EHa";
                break;
            case "-c": // "skip the link, do compile only"
                newArgs ~= "/c";
                compilingOnly = true;
                break;
            case "-cpp": // "source files are C++"
                newArgs ~= "/TP";
                break;
            case "-D": // "define macro DEBUG"
                newArgs ~= "/DDEBUG";
                break;
            case "-e": // "show results of preprocessor"
                break;
            case "-g": // "generate debug info"
            case "-gl": // "debug line numbers only"
                newArgs ~= "/Zi";
                break;
            case "-o": // "optimize for program speed"
                newArgs ~= "/O2";
                break;
            case "-wx": // "treat warnings as errors"
                newArgs ~= "/WX";
                break;
            default:
                if (arg.startsWith("-I")) // "#include file search path"
                {
                    foreach (path; arg[2..$].split(";"))
                        if (path != `\dm\include`)
                            newArgs ~= "/I" ~ path;
                }
                else
                if (arg.startsWith("-o")) // "output filename"
                    newArgs ~= "/F" ~ (compilingOnly ? "o" : "e") ~ arg[2..$];
                else
                if (arg[0] != '/' && arg[0] != '-' && !exists(arg) && exists(arg ~ ".c"))
                    newArgs ~= arg ~ ".c";
                else
                    newArgs ~= arg;
                break;
        }
    }
    stderr.writeln(escapeShellCommand(newArgs));
    return spawnProcess(newArgs).wait();
}
