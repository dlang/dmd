import dshell;

void main()
{
    const flags = "$DMD -m$MODEL -I$EXTRA_FILES/issue18723 ";
    run(flags ~ "-cov -c -of$OUTPUT_BASE/c$OBJ $EXTRA_FILES/issue18723/c.d");
    foreach (localCall; [false, true])
    {
        const versionFlag = localCall ? "-version=LocalCall " : "";
        run(flags ~ versionFlag ~ "-cov -c -of$OUTPUT_BASE/a$OBJ $EXTRA_FILES/issue18723/a.d");
        run(flags ~ versionFlag ~ "-cov=100 -c -of$OUTPUT_BASE/b$OBJ $EXTRA_FILES/issue18723/b.d");

        foreach (objects; ["a$OBJ $OUTPUT_BASE/b$OBJ", "b$OBJ $OUTPUT_BASE/a$OBJ"])
        {
            run("$DMD -m$MODEL -of$OUTPUT_BASE/check$EXE $OUTPUT_BASE/" ~ objects ~ " $OUTPUT_BASE/c$OBJ");
            checkCounts(localCall ? "2" : "1");
        }
    }

    // fromA is emitted into a deferred archive member. Both its own line
    // and the template line must be credited to the real source file.
    run(flags ~ "-version=LocalCall -cov -multiobj -lib -of$OUTPUT_BASE/a$LIBEXT $EXTRA_FILES/issue18723/a.d");
    run(flags ~ "-version=LocalCall -cov=100 -of$OUTPUT_BASE/check$EXE $EXTRA_FILES/issue18723/b.d $OUTPUT_BASE/a$LIBEXT $OUTPUT_BASE/c$OBJ");
    checkCounts("2", true);
}

void checkCounts(string twiceCount, bool archive = false)
{
    foreach (listing; dirEntries(OUTPUT_BASE, "*.lst", SpanMode.shallow))
        rm(listing.name);
    run([shellExpand("$OUTPUT_BASE/check$EXE"), "--DRT-covopt=merge:0 dstpath:" ~ OUTPUT_BASE]);

    string[] twice, triple, fromA;
    foreach (listing; dirEntries(OUTPUT_BASE, "*.lst", SpanMode.shallow))
    {
        foreach (line; listing.name.readText.splitLines)
        {
            if (line.endsWith("|    return x + x;"))
                twice ~= line.split('|')[0].strip;
            if (line.endsWith("|    return 3 * x;"))
                triple ~= line.split('|')[0].strip;
            if (line.endsWith("|    int fromA() { return twice(State!().value); }"))
                fromA ~= line.split('|')[0].strip;
        }
    }
    assert(twice == [twiceCount], format("expected %s for twice, got %s", twiceCount, twice));
    assert(triple == ["1"], format("expected 1 for triple, got %s", triple));
    if (archive)
        assert(fromA == ["1"], format("expected 1 for fromA, got %s", fromA));
}
