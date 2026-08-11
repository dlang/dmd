module app;

import std.file : mkdirRecurse, tempDir, write;
import std.getopt : getopt;
import std.parallelism : task;
import std.path : buildPath, dirName;
import std.stdio : stderr, writeln;

import metrics : measure, initials;
import report : MetricResult, render, Report;
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
    string outPath = "results.json";
    long pr;

    auto help = getopt(args,
        "base-dmd", "path to the base (merge-base) dmd binary", &baseDmd,
        "head-dmd", "path to the head (PR) dmd binary", &headDmd,
        "base-phobos", "path to the base phobos checkout", &basePhobos,
        "head-phobos", "path to the head phobos checkout", &headPhobos,
        "base-sha", "base commit sha (metadata)", &baseSha,
        "head-sha", "head commit sha (metadata)", &headSha,
        "pr",       "pull request number (metadata)", &pr,
        "os",       "runner OS label (metadata)", &os,
        "host-dmd", "bootstrap dmd version (metadata)", &hostDmd,
        "out",      "where to write results.json", &outPath,
    );

    if (help.helpWanted)
    {
        writeln("usage: perfrunner --base-dmd <path> --head-dmd <path> "
            ~ "--base-phobos <dir> --head-phobos <dir> "
            ~ "[--base-sha <sha> --head-sha <sha> --pr <n>] --out results.json");
        return 0;
    }

    if (baseDmd.length == 0 || headDmd.length == 0
        || basePhobos.length == 0 || headPhobos.length == 0)
    {
        stderr.writeln("error: --base-dmd, --head-dmd, --base-phobos and --head-phobos are required");
        return 2;
    }

    auto tmp = buildPath(tempDir, "perfrunner");
    mkdirRecurse(tmp);

    // Resolved once so both refs compile vibe.d with the same flags.
    auto vibedFlags = describeFlags(vibedDir, baseDmd);

    // measure base in a second thread while this one does head
    auto baseTask = task!measure(baseDmd, workload, basePhobos, vibedRoot, vibedFlags, tmp, "base");
    baseTask.executeInNewThread();
    auto head = measure(headDmd, workload, headPhobos, vibedRoot, vibedFlags, tmp, "head");
    auto base = baseTask.yieldForce;

    MetricResult[] metrics;
    foreach (def; initials)
        metrics ~= MetricResult(def.id, def.label, def.unit, def.method,
            base.metrics[def.id], head.metrics[def.id]);

    auto rep = Report(baseSha, "merge-base", headSha, pr, os, hostDmd, metrics,
        base.helloTrace, head.helloTrace, base.phobosTrace, head.phobosTrace);
    write(outPath, render(rep));
    writeln("wrote ", outPath);
    return 0;
}
