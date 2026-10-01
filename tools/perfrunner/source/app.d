module app;

import std.file : mkdirRecurse, tempDir, write;
import std.getopt : getopt;
import std.parallelism : task;
import std.path : buildPath, dirName;
import std.stdio : stderr, writeln;

import metrics : collectTraces, initials, measure, MetricDef, selfBuild, selfBuildMs;
import report : CommitRecord, MetricResult, render, renderCommit, Report;
import vibed : describeFlags;

enum workloads = buildPath(__FILE_FULL_PATH__.dirName.dirName, "workloads");

// Initial workload: the one source file compile to measure DMD.
enum workload = buildPath(workloads, "hello.d");

enum vibedDir = buildPath(workloads, "vibed");
enum vibedRoot = buildPath(vibedDir, "source", "app.d");

version (unittest) {} else
int main(string[] args)
{
    string baseDmd, headDmd, basePhobos, headPhobos, baseSha, headSha, hostDmd, os;
    string baseSrc, headSrc, hostDmdBin;
    string before, committedAt;
    string outPath = "results.json";
    long pr, commits = 1;

    auto help = getopt(args,
        "base-dmd", "path to the base (merge-base) dmd binary", &baseDmd,
        "head-dmd", "path to the head (PR) dmd binary", &headDmd,
        "base-phobos", "path to the base phobos checkout", &basePhobos,
        "head-phobos", "path to the head phobos checkout", &headPhobos,
        "base-src", "path to the base dmd source tree (self-build timing)", &baseSrc,
        "head-src", "path to the head dmd source tree (self-build timing)", &headSrc,
        "host-dmd-bin", "host compiler command for the self-build timing", &hostDmdBin,
        "base-sha", "base commit sha (metadata)", &baseSha,
        "head-sha", "head commit sha (metadata)", &headSha,
        "pr",       "pull request number (metadata)", &pr,
        "before",   "sha master pointed at before the push (metadata)", &before,
        "commits",  "commits contained in the push (metadata)", &commits,
        "committed-at", "commit timestamp (metadata)", &committedAt,
        "os",       "runner OS label (metadata)", &os,
        "host-dmd", "bootstrap dmd version (metadata)", &hostDmd,
        "out",      "where to write results.json", &outPath,
    );

    if (help.helpWanted)
    {
        writeln("usage: perfrunner --head-dmd <path> --head-phobos <dir> "
            ~ "[--base-dmd <path> --base-phobos <dir>] "
            ~ "[--base-sha <sha> --head-sha <sha> --pr <n>] --out results.json");
        writeln("without a base the single commit is measured for the history repo");
        return 0;
    }

    if (headDmd.length == 0 || headPhobos.length == 0)
    {
        stderr.writeln("error: --head-dmd and --head-phobos are required");
        return 2;
    }

    immutable diff = baseDmd.length != 0;
    if (diff && basePhobos.length == 0)
    {
        stderr.writeln("error: --base-dmd needs --base-phobos");
        return 2;
    }

    auto tmp = buildPath(tempDir, "perfrunner");
    mkdirRecurse(tmp);

    // Resolved once so both refs compile vibe.d with the same flags.
    auto vibedFlags = describeFlags(vibedDir, diff ? baseDmd : headDmd);

    if (!diff)
    {
        auto m = measure(headDmd, workload, headPhobos, vibedRoot, vibedFlags, tmp, "head");
        auto t = collectTraces(headDmd, workload, headPhobos, tmp, "head");
        if (headSrc.length && hostDmdBin.length)
            m[selfBuild.id] = selfBuildMs(headSrc, hostDmdBin);
        write(outPath, renderCommit(CommitRecord(headSha, committedAt, before, commits,
            os, hostDmd, m, t.hello, t.phobos)));
        writeln("wrote ", outPath);
        return 0;
    }

    // measure base in a second thread while this one does head
    auto baseTask = task!measure(baseDmd, workload, basePhobos, vibedRoot, vibedFlags, tmp, "base");
    baseTask.executeInNewThread();
    auto head = measure(headDmd, workload, headPhobos, vibedRoot, vibedFlags, tmp, "head");
    auto base = baseTask.yieldForce;

    auto baseTraces = collectTraces(baseDmd, workload, basePhobos, tmp, "base");
    auto headTraces = collectTraces(headDmd, workload, headPhobos, tmp, "head");

    immutable(MetricDef)[] defs = initials;
    if (baseSrc.length && headSrc.length && hostDmdBin.length)
    {
        base[selfBuild.id] = selfBuildMs(baseSrc, hostDmdBin);
        head[selfBuild.id] = selfBuildMs(headSrc, hostDmdBin);
        defs ~= selfBuild;
    }

    MetricResult[] metrics;
    foreach (def; defs)
        metrics ~= MetricResult(def.id, def.label, def.unit, def.method,
            base[def.id], head[def.id]);

    auto rep = Report(baseSha, "merge-base", headSha, pr, os, hostDmd, metrics,
        baseTraces.hello, headTraces.hello, baseTraces.phobos, headTraces.phobos);
    write(outPath, render(rep));
    writeln("wrote ", outPath);
    return 0;
}
