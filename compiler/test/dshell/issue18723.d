import dshell;
import std.algorithm : canFind;

void main()
{
    const flags = "$DMD -m$MODEL -I$EXTRA_FILES/issue18723 ";
    foreach (localCall; [false, true])
    {
        const versionFlag = localCall ? "-version=LocalCall " : "";
        run(flags ~ versionFlag ~ "-cov -c -of$OUTPUT_BASE/a$OBJ $EXTRA_FILES/issue18723/a.d");
        run(flags ~ versionFlag ~ "-cov=100 -c -of$OUTPUT_BASE/b$OBJ $EXTRA_FILES/issue18723/b.d");

        foreach (objects; ["a$OBJ $OUTPUT_BASE/b$OBJ", "b$OBJ $OUTPUT_BASE/a$OBJ"])
        {
            run("$DMD -m$MODEL -of$OUTPUT_BASE/check$EXE $OUTPUT_BASE/" ~ objects);
            run([shellExpand("$OUTPUT_BASE/check$EXE"), "--DRT-covopt=merge:0 dstpath:" ~ OUTPUT_BASE]);
            size_t matches;
            foreach (listing; dirEntries(OUTPUT_BASE, "*.lst", SpanMode.shallow))
            {
                foreach (line; listing.name.readText.splitLines)
                {
                    if (line.endsWith("|    return x + x;"))
                    {
                        ++matches;
                        assert(line.split('|')[0].strip == (localCall ? "2" : "1"), line);
                    }
                }
            }
            assert(matches == 1, "expected one listing for the template body");
        }
    }

    // fromA is emitted into a deferred archive member. Both its own line
    // and the template line must be credited to the real source file.
    run(flags ~ "-version=LocalCall -cov -multiobj -lib -of$OUTPUT_BASE/a$LIBEXT $EXTRA_FILES/issue18723/a.d");
    run(flags ~ "-version=LocalCall -cov=100 -of$OUTPUT_BASE/check$EXE $EXTRA_FILES/issue18723/b.d $OUTPUT_BASE/a$LIBEXT");
    const reports = buildPath(OUTPUT_BASE, "multiobj");
    mkdirRecurse(reports);
    run([shellExpand("$OUTPUT_BASE/check$EXE"), "--DRT-covopt=merge:0 dstpath:" ~ reports]);
    size_t matches;
    foreach (listing; dirEntries(reports, "*.lst", SpanMode.shallow))
    {
        const lines = listing.name.readText.splitLines;
        if (!lines.canFind!(line => line.endsWith("|    return x + x;")))
            continue;
        ++matches;
        assert(lines.canFind!(line => line.strip == "2|    return x + x;"));
        assert(lines.canFind!(line => line.strip == "1|    int fromA() { return twice(4); }"));
    }
    assert(matches == 1);
}
