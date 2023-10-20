/**
 * Helper script to copy source files to the `import` directory
 *
 * When building druntime, files in `src` are copied to the `import` directory, excluding modules from
 * the `rt` and `gc` packages and a couple more non-public files.
 * On POSIX this is handled by a Makefile rule, however DigitalMars' `make` on Windows has very limited support for
 * custom rules, originally leading to an unhealthy duplication between mak/COPY and mak/WINDOWS,
 * which this script removes.
 */
module copyimports;

import std.array, std.conv, std.file, std.getopt, std.path, std.stdio;
import core.stdc.stdlib;

void main(string[] args)
{
    // DigitalMars make passes long command line through this environment variable _CMDLINE
    if (auto p = getenv("_CMDLINE"))
        args = split(to!string(p));
    else
        args = args[1..$];

    string importPath = absolutePath("import");
    string srcPath = absolutePath("src");
    foreach(file; args)
    {
        string impfile = absolutePath(file);
        string srcfile = buildPath(srcPath, asRelativePath(impfile, importPath).array);
        if (std.file.exists(impfile))
        {
            if (timeLastModified(impfile) >= timeLastModified(srcfile))
                continue;
            writeln("updating ", file);
        }
        else
            writeln("creating ", file);

        mkdirRecurse(dirName(impfile));
        std.file.copy(srcfile, impfile);
    }
}
