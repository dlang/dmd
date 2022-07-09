/**
 * Run the C preprocessor on a C source file.
 *
 * Specification: C11
 *
 * Copyright:   Copyright (C) 2022 by The D Language Foundation, All Rights Reserved
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
import dmd.target;
import dmd.vsoptions;

import dmd.common.outbuffer;

import dmd.root.array;
import dmd.root.filename;
import dmd.root.rmem;
import dmd.root.rootobject;
import dmd.root.string;

// Use default for other versions
version (Posix)   version = runPreprocessor;
version (Windows) version = runPreprocessor;


/***************************************
 * Preprocess C file.
 * Params:
 *      csrcfile = C file to be preprocessed, with .c or .h extension
 *      loc = The source location where preprocess is requested from
 *      ifile = set to true if an output file was written
 *      defines = buffer to append any `#define` and `#undef` lines encountered to
 * Result:
 *      filename of output
 */
extern (C++)
FileName preprocess(FileName csrcfile, ref const Loc loc, out bool ifile, OutBuffer* defines)
{
    /* Look for "importc.h" by searching along import path.
     * It should be in the same place as "object.d"
     */
    const(char)* importc_h;

    foreach (entry; (global.path ? (*global.path)[] : null))
    {
        auto f = FileName.combine(entry, "importc.h");
        if (FileName.exists(f) == 1)
        {
            importc_h = f;
            break;
        }
        FileName.free(f);
    }

    if (importc_h)
    {
        if (global.params.verbose)
            message("include   %s", importc_h);
    }
    else
    {
        error(loc, "cannot find \"importc.h\" along import path");
        fatal();
    }

    //printf("preprocess %s\n", csrcfile.toChars());
    version (runPreprocessor)
    {
        /*
           To get sppn.exe: http://ftp.digitalmars.com/sppn.zip
           To get the dmc C headers, dmc will need to be installed:
           http://ftp.digitalmars.com/Digital_Mars_C++/Patch/dm857c.zip
         */
        const name = FileName.name(csrcfile.toString());
        const ext = FileName.ext(name);
        assert(ext);
        const ifilename = FileName.addExt(name[0 .. name.length - (ext.length + 1)], i_ext);
        const command = cppCommand();
        auto status = runPreprocessor(command, csrcfile.toString(), importc_h, global.params.cppswitches, ifilename, defines);
        if (status)
        {
            error(loc, "C preprocess command %.*s failed for file %s, exit status %d\n",
                cast(int)command.length, command.ptr, csrcfile.toChars(), status);
            fatal();
        }
        //printf("C preprocess succeeded %s\n", ifilename.ptr);
        ifile = true;
        return FileName(ifilename);
    }
    else
        return csrcfile;        // no-op
}

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
            auto path = vsopt.compilerPath(target.is64bit);
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
