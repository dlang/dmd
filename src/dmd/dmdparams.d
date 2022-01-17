/**
 * DMD-specific parameters.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/dmdparams.d, _dmdparams.d)
 * Documentation:  https://dlang.org/phobos/dmd_dmdparams.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/dmdparams.d
 */

module dmd.dmdparams;

struct DMDparams
{
    bool alwaysframe;       // always emit standard stack frame
    ubyte dwarf;            // DWARF version
    bool map;               // generate linker .map file
    bool vasm;              // print generated assembler for each function

    // Hidden debug switches
    bool debugb;
    bool debugc;
    bool debugf;
    bool debugr;
    bool debugx;
    bool debugy;
}

shared DMDparams dmdParams = dmdParams.init;
