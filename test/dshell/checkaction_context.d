module test.dshell.checkaction_context;

import dshell_prebuilt;
import std.stdio;

int main()
{
    try
    {
        tryMain();
        return 0;
    }
    catch (Throwable t)
    {
        writeln(t.msg);
        return 1;
    }
}

void tryMain()
{
    // Somehow not called by the module ctor?
    dshellPrebuiltInit(`dshell`, `checkaction_context`);

    Vars.set("EXTRA", `$EXTRA_FILES/checkaction_context`);

    run("$DMD -m$MODEL -I$EXTRA -checkaction=D -c -of=$OUTPUT_BASE/library$OBJ $EXTRA/library.d");
    run("$DMD -m$MODEL -I$EXTRA -checkaction=context -of=$OUTPUT_BASE/root$EXE $OUTPUT_BASE/library$OBJ $EXTRA/root.d");

    run("$DMD -m$MODEL -checkaction=context -main -of=$OUTPUT_BASE/issue22700$EXE $EXTRA/issue22700.d");

    // Disabled for the CI to avoid Phobos dependency, current reduction in root.d + library.d
    // run("$DMD -g -checkaction=context $EXTRA/use_std.d");
}
