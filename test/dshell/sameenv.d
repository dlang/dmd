import dshell;
void main()
{
    const envFromExe = shellExpand("$OUTPUT_BASE/envFromExe.txt");
    const envFromRun = shellExpand("$OUTPUT_BASE/envFromRun.txt");

    run("$DMD -m$MODEL -of$OUTPUT_BASE/printenv$EXE $EXTRA_FILES/printenv.d");
    run("$OUTPUT_BASE/printenv$EXE", File(envFromExe, "wb"));
    run("$DMD -m$MODEL -run $EXTRA_FILES/printenv.d", File(envFromRun, "wb"));

    const fromExe = readText(envFromExe);
    const fromRun = readText(envFromRun);
    if (fromExe != fromRun)
    {
        writefln("FromExe:");
        writeln("-----------");
        writeln(fromExe);
        writefln("FromRun:");
        writeln("-----------");
        writeln(fromRun);
        assert(0, "output from exe/run differ");
    }
}
