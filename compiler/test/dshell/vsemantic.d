import dshell;

int main()
{
    const source = OUTPUT_BASE ~ ".d";
    const trace = OUTPUT_BASE ~ " trace.tsv"; // also exercise a path containing spaces
    const diagnostics = OUTPUT_BASE ~ ".err";
    scope (exit) rm(source, trace, diagnostics);
    std.file.write(source, "module object; int f()(int n) { return n ? f(n - 1) : 0; } void g() { f(1); }");

    auto command = [DMD, "-m" ~ MODEL, "-c", "-o-", source];
    rm(trace);
    run(command);
    assert(!exists(trace));

    auto output = File(diagnostics, "w");
    run(command ~ ["-vsemantic=" ~ trace], output, output);
    output.close();
    assert(readText(diagnostics).length == 0);
    const text = readText(trace);
    assert(text.startsWith("1\tparent=0\tevent=request\t"));
    assert(text.indexOf("reason=already-active") >= 0);
    assert(text.indexOf("event=start\treason=function-semantic3") >= 0);
    assert(text.indexOf("event=finish\treason=completed") >= 0);

    foreach (option; ["-vsemantic", "-vsemantic="])
    {
        output = File(diagnostics, "w");
        assert(tryRun(command ~ [option], output, output) != 0);
        output.close();
        assert(readText(diagnostics).indexOf("argument expected for switch") >= 0);
    }
    return 0;
}
