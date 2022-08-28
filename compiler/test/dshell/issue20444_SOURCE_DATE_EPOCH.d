import dshell;

immutable string expected =
`Apr 24 1992
14:14:00
Fri Apr 24 14:14:00 1992
`;

void main ()
{
    string[string] env = [
        "SOURCE_DATE_EPOCH": "704124840",
        "TZ": "UTC",
        "LC_ALL": "C",
    ];

    const output = shellExpand("$OUTPUT_BASE/source_date_epoch.txt");
    run("$DMD -m$MODEL -o- -c $EXTRA_FILES/source_date_epoch.d", stdout, File(output, "wb"), env);
    const result = readText(output).filterCompilerOutput;
    assert(result == expected, result);
}
