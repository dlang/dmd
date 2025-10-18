// $ rdmd -version=DDoTestNoMain -version=NoMain -i -Itools tools/find_groupable.d <testdir>
// Find tests that may be groupable.
// Used in speeding up the dmd's testsuite.

import std.array;
import std.file;
import std.stdio;
import d_do_test;

void main(string[] args)
{
    string dir = args[1];

    EnvData env;
    env.sep = "/";

    TestArgs[][string][string] storage;

    foreach (de; dirEntries(dir, "*.d", SpanMode.shallow))
    {
        writeln("Trying file ", de);

        TestArgs targ;

        gatherTestParameters(targ, dir, de, env);

        if (targ.isDisabled)
            continue;
        else if (targ.compileOutput.length > 0 || targ.compileOutput.length > 0
                || targ.transformOutput.length > 0 || targ.outputFiles.length > 0
                || targ.gdbScript.length > 0 || targ.gdbMatch.length > 0
                || targ.runReturn != 0 || targ.runOutput.length > 0
                || targ.compileOutputFile.length > 0 || targ.argSets.length > 0
                || targ.objcSources.length > 0 || targ.cppSources.length > 0
                || targ.compiledImports.length > 0 || targ.cxxflags.length > 0
                || targ.executeArgs.replace(" --DRT-testmode=run-main", "")
                    .length > 0 || targ.clearDflags || targ.link || targ.compileSeparately)
        {
            continue;
        }

        storage[targ.requiredArgs][targ.permuteArgs] ~= targ;
    }

    foreach (req, reqs; storage)
    {
        writeln("Required: ", req);
        foreach (perm, targs; reqs)
        {
            writeln("    Permute: ", perm);
            foreach (ref arg; targs)
            {
                writeln("        Test: ", arg.sources);
            }
        }
    }
}
