module metrics;

import std.conv : to;
import std.file : copy, exists, getSize, remove;
import std.path : buildPath;
import std.regex : ctRegex, matchFirst;

import std.process : execute;

import cachegrind : instructions;

struct MetricDef
{
    string id;
    string label;
    string unit;
    string method;
}

// Some initial metrics to measure will add more later
immutable MetricDef[] initials = [
    MetricDef("compile_hello_debug_instr",   "compile hello.d (instr)",    "count", "cachegrind"),
    MetricDef("compile_hello_release_instr", "compile hello.d -O (instr)", "count", "cachegrind"),
    MetricDef("compile_phobos_instr",        "compile Phobos (instr)",     "count", "cachegrind"),
    MetricDef("dmd_binary_size",             "dmd binary size (stripped)", "bytes", "stat"),
    MetricDef("hello_binary_size",           "hello binary size",          "bytes", "stat"),
    MetricDef("hello_max_rss",               "peak RSS (compile hello.d)", "kb",    "time -v"),
    MetricDef("phobos_max_rss",              "peak RSS (compile Phobos)",  "kb",    "time -v"),
];

// Measure every metric for one dmd binary. `tag` ("base"/"head")
// keeps the two runs' temp files apart
long[string] measure(string dmd, string workload, string phobos, string tmp, string tag)
{
    auto stdPackage = buildPath(phobos, "std", "package.d");
    auto phobosFlags = ["-i=std", "-preview=dip1000"];
    return [
        "compile_hello_debug_instr":   instructions(dmd, [], workload, tmp, tag ~ "-dbg"),
        "compile_hello_release_instr": instructions(dmd, ["-O", "-release"], workload, tmp, tag ~ "-rel"),
        "compile_phobos_instr":        instructions(dmd, phobosFlags, stdPackage, tmp, tag ~ "-phobos"),
        "dmd_binary_size":             strippedSize(dmd, buildPath(tmp, tag ~ "-dmd")),
        "hello_binary_size":           helloSize(dmd, workload, tmp, tag),
        "hello_max_rss":               maxRss(dmd, [], workload, tmp, tag),
        "phobos_max_rss":              maxRss(dmd, phobosFlags, stdPackage, tmp, tag ~ "-phobos"),
    ];
}

// Byte size of `binary`
private long strippedSize(string binary, string copyPath)
{
    if (exists(copyPath))
        remove(copyPath);
    copy(binary, copyPath);
    strip(copyPath);
    return getSize(copyPath);
}

// Compile the workload to an executable and its size in bytes
private long helloSize(string dmd, string workload, string tmp, string tag)
{
    auto exe = buildPath(tmp, tag ~ "-hello");
    auto r = execute([dmd, workload, "-of=" ~ exe]);
    if (r.status != 0)
        throw new Exception("compiling hello executable failed:\n" ~ r.output);
    strip(exe);
    return getSize(exe);
}

private void strip(string path)
{
    auto r = execute(["strip", path]);
    if (r.status != 0)
        throw new Exception("strip failed:\n" ~ r.output);
}

// Peak RSS (KiB) of compiling the workload (/usr/bin/time)
private long maxRss(string dmd, string[] dflags, string workload, string tmp, string tag)
{
    auto obj = buildPath(tmp, tag ~ "-rss.o");
    auto cmd = ["/usr/bin/time", "-v", dmd, "-c"] ~ dflags ~ [workload, "-of=" ~ obj];
    auto r = execute(cmd);
    if (r.status != 0)
        throw new Exception("/usr/bin/time failed:\n" ~ r.output);
    return parseMaxRss(r.output);
}

private enum rssRe = ctRegex!(`Maximum resident set size \(kbytes\):\s+(\d+)`);

// Pull the max-RSS value (KiB) out of `/usr/bin/time -v` output.
long parseMaxRss(string output)
{
    auto m = matchFirst(output, rssRe);
    if (m.empty)
        throw new Exception("could not parse max RSS");
    return m[1].to!long;
}

unittest
{
    auto sample = "\tMaximum resident set size (kbytes): 184320\n";
    assert(parseMaxRss(sample) == 184320);
}
