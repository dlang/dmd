module app;

import std.file : mkdirRecurse, tempDir, write;
import std.getopt : getopt;
import std.path : buildPath, dirName;
import std.stdio : stderr, writeln;

import metrics : measure, initials;
import report : MetricResult, render, Report;

// Initial workload: the one source file compile to measure DMD.
enum workload = buildPath(__FILE_FULL_PATH__.dirName.dirName, "workloads", "hello.d");

version (unittest) {} else
int main(string[] args)
{
    string baseDmd, headDmd, basePhobos, headPhobos, baseSha, headSha, hostDmd;
    string os = "ubuntu-latest";
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

    auto base = measure(baseDmd, workload, basePhobos, tmp, "base");
    auto head = measure(headDmd, workload, headPhobos, tmp, "head");

    MetricResult[] metrics;
    foreach (def; initials)
        metrics ~= MetricResult(def.id, def.label, def.unit, def.method,
            base[def.id], head[def.id]);

    auto rep = Report(baseSha, "merge-base", headSha, pr, os, hostDmd, metrics);
    write(outPath, render(rep));
    writeln("wrote ", outPath);
    return 0;
}
