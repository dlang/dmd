#!/usr/bin/env dub
/+
    dub.sdl:
    name "parse_tagged_hier"
+/

import std.algorithm;
import std.array;
import std.conv: to;
import std.file;
import std.exception: enforce;
import std.path;
import std.stdio;
import std.string: splitLines;
import std.typecons;

int main(in string[] args)
{
    try
        worker(args);
    catch(Exception e)
    {
        stderr.writeln("Error: "~e.msg);
        return 1;
    }

    return 0;
}

void worker(in string[] args)
{
    enforce(args.length >= 7 && args.length <= 8, "need 6 or 7 CLI arguments");

    immutable dstFile = args[1].buildNormalizedPath; /// i.e. GEN_SRCS file
    immutable taggedImportsFile = args[2].buildNormalizedPath; /// i.e. mak/TAGGED_COPY
    immutable dstCopyFile = args[3].buildNormalizedPath; /// i.e. GEN_COPY file, generated list of imports choised by tags
    immutable impDir = args[4].buildNormalizedPath; /// path to druntime ./import/ dir
    immutable tagsArg = args[5]; /// comma separated list of tags
    immutable configDir = args[6]; /// path to druntime config/ dir where is placed tags implementations
    immutable externalConfigDir = (args.length > 7) ? args[7] : null; /// path to additional (external) config/ dir

    enforce(taggedImportsFile.isFile, `Tagged imports file '`~taggedImportsFile~`' not found`);
    enforce(configDir.isDir, `Tags implementations dir '`~configDir~`' not found`);

    if(externalConfigDir !is null)
        enforce(externalConfigDir.isDir, `Additional tags dir '`~externalConfigDir~`' not found`);

    immutable string[] tags = tagsArg.split(",");

    writeln("Tags will be applied: ", tagsArg);

    immutable allConfigDirs = [configDir, externalConfigDir];

    auto availTagsDirs = allConfigDirs
        .map!(a => a.dirEntries(SpanMode.shallow))
        .join
        .filter!(a => a.isDir)
        .map!(a => Tuple!(string, "base", string, "path")(a.name.baseName, a.name))
        .array
        .sort!((a, b) => a.base < b.base);

    static struct SrcElem
    {
        string basePath;    // ~/a/b/c/confing_dir/tag_1_name
        string tag;         // tag_1_name
        string relPath;     // core/internal/somemodule.d

        string fullPath() const
        {
            return basePath~"/"~relPath; // ~/a/b/c/confing_dir/tag_1_name/core/internal/somemodule.d
        }
    }

    SrcElem[] resultSrcsList;

    foreach(tag; tags)
    {
        auto foundSUbdirs = availTagsDirs.filter!(a => a.base == tag);

        if(foundSUbdirs.empty)
        {
            stderr.writeln(`Warning: tag '`, tag, `' doesn't corresponds to any subdirectory inside of '`, allConfigDirs,`', skip`);
            continue;
        }

        // tag matched, files from matching dirs should be added to list recursively
        auto filesToAdd = foundSUbdirs.map!(
                d => dirEntries(d.path, SpanMode.depth)
                    .filter!(a => a.isFile)
                    .map!(e => SrcElem(d.path, tag, e.name[d.path.length+1 .. $]))
            ).join;

        foreach(f; filesToAdd)
        {
            auto found = resultSrcsList.find!((a, b) => a.relPath == b.relPath)(f);

            enforce(found.empty, `File '`~f.fullPath~`' overrides already defined file '`~found.front.fullPath~`'`);

            resultSrcsList ~= f;
        }
    }

    auto taggedImportsList = taggedImportsFile.readText.replace(`\`, `/`).splitLines.sort.uniq.array;
    auto importsToCopy = File(dstCopyFile, "w");

    foreach(imp; taggedImportsList)
    {
        auto found = resultSrcsList.find!(a => a.relPath == imp);
        enforce(!found.empty, `Required for import file '`~imp~`' is not found in tagged sources`);

        importsToCopy.writeln(found.front.fullPath);
    }

    resultSrcsList.map!(a => a.fullPath).join("\n").toFile(dstFile);

    writeln("All tags applied");
}
