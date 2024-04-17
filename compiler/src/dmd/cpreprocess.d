/**
 * Run the C preprocessor on a C source file.
 *
 * Specification: C11
 *
 * Copyright:   Copyright (C) 2022-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/cpreprocess.d, _cpreprocess.d)
 * Documentation:  https://dlang.org/phobos/dmd_cpreprocess.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/cpreprocess.d
 */

module dmd.cpreprocess;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.astenums;
import dmd.errors;
import dmd.globals;
import dmd.link;
import dmd.location;
import dmd.target;
import dmd.vsoptions;

import dmd.common.outbuffer;

import dmd.root.array;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.root.string;

// Use default for other versions
version (Posix)         enum preprocessorAvailable = true;
else version (Windows)  enum preprocessorAvailable = true;
else enum preprocessorAvailable = false;

/***************************************
 * Preprocess C file.
 * Params:
 *      csrcfile = C file to be preprocessed, with .c or .h extension
 *      loc = The source location where preprocess is requested from
 *      alreadyPreprocessed = True if file have .i extension
 *      defines = buffer to append any `#define` and `#undef` lines encountered to
 * Result:
 *      the text of the preprocessed file
 */
extern (C++)
DArray!(const ubyte) preprocess(FileName csrcfile, ref const Loc loc, bool alreadyPreprocessed, ref OutBuffer defines)
{
    /* Look for "importc.h" by searching along import path.
     */
    const(char)* importc_h = findImportcH(global.path[]);

    if (importc_h)
    {
        if (global.params.v.verbose)
            message("include   %s", importc_h);
    }
    else
    {
        error(loc, "cannot find \"importc.h\" along import path");
        fatal();
    }

    //printf("preprocess %s\n", csrcfile.toChars());
    if (preprocessorAvailable && global.params.usePreprocessor)
    {
        const command = global.params.cpp ? toDString(global.params.cpp) : cppCommand();

        version (Windows)   enum canPreprocessTwice = false;
        else enum canPreprocessTwice = true;

        static if(!canPreprocessTwice)
        {
            // Some preprocessors can't parse already parsed files
            // We should remove lines starting with "# " to pretend what
            // preprocessed file wasn't preprocessed

            FileName tmp_filename;

            if (alreadyPreprocessed)
            {
                import dmd.utils : writeFile;

                auto src = global.fileManager.getFileContents(csrcfile);

                tmp_filename = FileName(csrcfile.toString ~ ".tmp.i");

                string dst;
                foreach (line; (cast(char[]) src).splitLines)
                    dst ~= line.ptr.startsWith("# ") ? "\n" : (line~'\n');

                if (!writeFile(loc, tmp_filename.toString, dst))
                    fatal();

                csrcfile = tmp_filename;
            }

            scope (exit)
            {
                if(tmp_filename.toChars !is null)
                    File.remove(tmp_filename.toChars);
            }
        }

        DArray!(const ubyte) text;
        int status = runPreprocessor(loc, command, csrcfile.toString(), alreadyPreprocessed,
            importc_h, global.params.cppswitches, global.params.v.verbose, global.errorSink,
            defines, text
        );

        if (status)
            fatal();
        return text;
    }
    else
    {
        return DArray!(const ubyte)(global.fileManager.getFileContents(csrcfile));
    }
}


/***************************************
 * Find importc.h by looking along the path
 * Params:
 *      path = import path
 * Returns:
 *      importc.h file name, null if not found
 */
const(char)* findImportcH(const(char)*[] path)
{
    /* Look for "importc.h" by searching along import path.
     * It should be in the same place as "object.d"
     */
    foreach (entry; path)
    {
        auto f = FileName.combine(entry, "importc.h");
        if (FileName.exists(f) == 1)
        {
            return FileName.toAbsolute(f);
        }
        FileName.free(f);
    }
    return null;
}

/******************************************
 * Pick the C preprocessor program to run.
 */
private const(char)[] cppCommand()
{
    if (auto p = getenv("CPPCMD"))
        return toDString(p);

    version (Windows)
    {
        if (target.objectFormat() == Target.ObjectFormat.coff)
        {
            VSOptions vsopt;
            vsopt.initialize();
            auto path = vsopt.compilerPath(target.isX86_64);
            return toDString(path);
        }
        if (target.objectFormat() == Target.ObjectFormat.omf)
        {
            return "sppn.exe";
        }
        // Perhaps we are cross-compiling.
        return "cpp";
    }
    else version (OpenBSD)
    {
        // On OpenBSD, we need to use the actual binary /usr/libexec/cpp
        // rather than the shell script wrapper /usr/bin/cpp ...
        // Turns out the shell script doesn't really understand -o
        return "/usr/libexec/cpp";
    }
    else version (OSX)
    {
        return "clang";
    }
    else
    {
        return "cpp";
    }
}
