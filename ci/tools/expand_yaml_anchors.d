#!/usr/bin/env dub
/+ dub.sdl:
    dependency "dyaml" version="~>0.8.4"
+/

import std.array;
import std.format : format;
import std.file;
import std.getopt;
import std.stdio;
import dyaml;

static immutable fileHeader =
q"{
######################################################################
#   WARNING: This file was automatically generated. DO NOT MODIFY!   #
######################################################################
# This file was automatically generated from '%s'. To modify this file,
# you should modify the source file, and call 'ci/tools/expand_yaml_anchors.d'.
# Do not modify this file directly, as changes will most likely be lost.
}";

void main(string[] args)
{
    bool force = false, verbose = false;
    string infolder = "ci/src/gh-actions", outfolder = ".github/workflows";

    auto opts = getopt(args,
        "i|input",
            "The input directory to read from",
            &infolder,
        "o|output",
            "The output directory to output files to",
            &outfolder,
        "f|force",
            "Write over existing files",
            &force,
        "v|verbose",
            "Print verbose output",
            &verbose
        );

    if (opts.helpWanted) {
        defaultGetoptPrinter("YAML anchor expander (for GitHub Actions workflows)",
            opts.options);
        return;
    }

    assert(infolder.exists && outfolder.exists, "Expected both input / output to exist");
    assert(infolder.isDir && outfolder.isDir, "Expected both input / output folders to be folders");

    foreach (string name; dirEntries(infolder, "*.yml", SpanMode.shallow))
    {
        import std.path;

        writefln("Processing %s...", name);
        try {
            auto root = Loader.fromFile(name).load();

            if (root.nodeID == NodeID.mapping) {
                if (root.containsKey("x-meta-anchors-remove")) {
                    root.removeAt("x-meta-anchors-remove");
                }
            }

            auto outPath = buildPath(outfolder, name.baseName);
            if (outPath.exists && !force)
            {
                writefln("%s exists, refusing to write over..", outPath);
                continue;
            }
            else
            {
                import std.regex;
                import std.string : stripLeft;

                writefln("Writing out results to %s", outPath);
                // Write the file header
                auto file = File(outPath, "w");
                file.writef("%s", format(fileHeader, name).stripLeft);
                auto appender = appender!string();
                // Then create our dumper
                auto dumper = dumper();
                dumper.defaultScalarStyle = ScalarStyle.plain;
                dumper.canonical = false;
                // This isn't meant to be human-readable...
                dumper.textWidth = uint.max - 1;
                // We don't need the explicit YAML version or start / end..
                dumper.explicitEnd = false;
                dumper.explicitStart = false;
                dumper.YAMLVersion = null;
                dumper.dump(appender, root);

                // Ugh. D-YAML *loves* to output these stupid tag prefixes, which breaks GitHub Actions
                // So, we have to do a hack and strip it out. Yuck.
                auto re = regex(`(!!\w* )`);
                file.writef("%s", appender.data.replaceAll(re, ""));
            }
        } catch (Exception e) {
            writefln("Caught exception while trying to read %s, skipping...", name);
            if (verbose) {
                writefln("Exception: %s", e.msg);
            }
        }

    }

    writefln("Done!");
}
