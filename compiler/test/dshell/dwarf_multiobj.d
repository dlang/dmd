/* `-lib` splits a module into several objects, each named after a
 * doppelganger of the module: the `DW_TAG_module` of every object must
 * still carry the name of the original module.
 */
import dshell;

import std.algorithm;
import std.process;
import std.string;

int main()
{
    version (Windows)
        return DISABLED;
    else version (OSX)
        return DISABLED;
    else
    {
        if (executeShell("objdump --version").status)
            return DISABLED;

        Vars.set("lib", "$OUTPUT_BASE/dwarf_multiobj$LIBEXT");
        run("$DMD -m$MODEL -g -lib -of$lib $EXTRA_FILES/dwarf_multiobj.d");

        const dump = executeShell(shellExpand("objdump --dwarf=info $lib"), ["LANG": "C"]);
        assert(!dump.status, dump.output);

        string[] names;
        bool inModule;
        foreach (line; dump.output.lineSplitter)
        {
            if (line.canFind("(DW_TAG_"))
                inModule = line.canFind("(DW_TAG_module)");
            else if (inModule && line.canFind("DW_AT_name"))
                names ~= line[line.indexOf(": ") + 2 .. $].strip;
        }

        // The module must have been split for this test to be meaningful
        assert(names.length > 1, dump.output);
        foreach (name; names)
            assert(name == "pkg.dwarf_multiobj", "Wrong module name: " ~ name);
        return 0;
    }
}
