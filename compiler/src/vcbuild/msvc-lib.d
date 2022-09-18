/// Wrapper which accepts DM lib.exe command-line syntax
/// and passes the transformed options to a MSVC lib.exe.
module msvc_lib;

import std.algorithm.searching;
import std.array;
import std.file;
import std.path;
import std.process;
import std.stdio;

int main(string[] args)
{
    auto lib = environment.get("MSVC_AR",
        environment.get("VCINSTALLDIR", `\Program Files (x86)\Microsoft Visual Studio 10.0\VC\`)
            .buildPath("bin", "amd64", "lib.exe"));
    string[] newArgs = [lib];
    newArgs ~= "/NOLOGO";

    foreach (arg; args[1..$])
    {
        switch (arg)
        {
            case "-n": // "do not create backup file"
            case "-c": // "create"
                break;
            default:
                if (arg.startsWith("-p")) // "set page size to nnn (a power of 2)"
                    continue;
                if (arg.endsWith(".lib"))
                    newArgs ~= "/OUT:" ~ arg;
                else
                    newArgs ~= arg;
                break;
        }
    }
    stderr.writeln(escapeShellCommand(newArgs));
    return spawnProcess(newArgs).wait();
}
