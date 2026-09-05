module report;

import std.json : JSONValue, parseJSON;
import std.math : round;

import stats : deltaPct;
import timetrace : Trace, phaseIds;

struct MetricResult
{
    string id;
    string label;
    string unit;
    string method;
    long base;
    long head;
}

struct Report
{
    string baseSha;
    string baseRef;
    string headSha;
    long pr;
    string os;
    string hostDmd;
    MetricResult[] metrics;
    Trace helloBase, helloHead;
    Trace phobosBase, phobosHead;
}

// One master commit measured on its own.
struct CommitRecord
{
    string sha;
    string committedAt;
    string before;
    long commits;
    string os;
    string hostDmd;
    long[string] metrics;
    Trace hello, phobos;
}

// Serialise a report to the initial schema
string render(Report rep)
{
    JSONValue[] metrics;
    foreach (m; rep.metrics)
    {
        metrics ~= JSONValue([
            "id":        JSONValue(m.id),
            "label":     JSONValue(m.label),
            "unit":      JSONValue(m.unit),
            "method":    JSONValue(m.method),
            "base":      JSONValue(m.base),
            "head":      JSONValue(m.head),
            "delta_pct": JSONValue(round(deltaPct(m.base, m.head) * 100) / 100.0),
        ]);
    }

    JSONValue root = [
        "schema_version": JSONValue(2),
        "base":   JSONValue(["sha": JSONValue(rep.baseSha), "ref": JSONValue(rep.baseRef)]),
        "head":   JSONValue(["sha": JSONValue(rep.headSha), "pr": JSONValue(rep.pr)]),
        "runner": JSONValue(["os": JSONValue(rep.os), "host_dmd": JSONValue(rep.hostDmd)]),
        "metrics": JSONValue(metrics),
        "time_trace": JSONValue([
            "hello":  traceJson(rep.helloBase, rep.helloHead),
            "phobos": traceJson(rep.phobosBase, rep.phobosHead),
        ]),
    ];

    return root.toPrettyString();
}

// Serialise a single-commit measurement for the history repo
string renderCommit(CommitRecord rec)
{
    JSONValue[string] metrics;
    foreach (id, value; rec.metrics)
        metrics[id] = JSONValue(value);

    JSONValue root = [
        "schema_version": JSONValue(3),
        "commit":       JSONValue(rec.sha),
        "committed_at": JSONValue(rec.committedAt),
        "push":    JSONValue(["before": JSONValue(rec.before), "commits": JSONValue(rec.commits)]),
        "runner":  JSONValue(["os": JSONValue(rec.os), "host_dmd": JSONValue(rec.hostDmd)]),
        "metrics": JSONValue(metrics),
        "time_trace": JSONValue([
            "hello":  traceJson(rec.hello),
            "phobos": traceJson(rec.phobos),
        ]),
    ];

    return root.toPrettyString();
}

private JSONValue pair(long base, long head)
{
    return JSONValue(["base": JSONValue(base), "head": JSONValue(head)]);
}

private JSONValue traceJson(Trace b, Trace h)
{
    JSONValue[string] phases;
    foreach (id; phaseIds)
        phases[id] = pair(b.phase(id), h.phase(id));

    return JSONValue([
        "total_us": pair(b.total, h.total),
        "phases":   JSONValue(phases),
    ]);
}

private JSONValue traceJson(Trace t)
{
    JSONValue[string] phases;
    foreach (id; phaseIds)
        phases[id] = JSONValue(t.phase(id));

    return JSONValue([
        "total_us": JSONValue(t.total),
        "phases":   JSONValue(phases),
    ]);
}

unittest
{
    auto rep = Report("base1", "merge-base", "head1", 7, "ubuntu-latest", "2.112.0",
        [MetricResult("compile_hello_debug_instr", "compile hello.d (instr)",
            "count", "cachegrind", 1000, 1010)]);

    auto j = parseJSON(render(rep));
    assert(j["schema_version"].integer == 2);
    assert(j["base"]["sha"].str == "base1");
    assert(j["head"]["pr"].integer == 7);
    assert(j["metrics"].array.length == 1);

    auto m = j["metrics"][0];
    assert(m["id"].str == "compile_hello_debug_instr");
    assert(m["base"].integer == 1000);

    import std.math : isClose;
    assert(isClose(m["delta_pct"].floating, 1.0));
}

unittest
{
    auto rec = CommitRecord("head1", "2026-07-30T09:12:44Z", "before1", 3,
        "ubuntu-latest", "ldc-1.42.0", ["compile_hello_debug_instr": 1000L]);

    auto j = parseJSON(renderCommit(rec));
    assert(j["schema_version"].integer == 3);
    assert(j["commit"].str == "head1");
    assert(j["push"]["commits"].integer == 3);
    assert(j["metrics"]["compile_hello_debug_instr"].integer == 1000);
    assert(j["time_trace"]["hello"]["total_us"].integer == 0);
}
