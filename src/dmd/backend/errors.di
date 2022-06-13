/**
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/errors.d, _errors.d)
 * Documentation:  https://dlang.org/phobos/dmd_errors.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/errors.d
 */
module dmd.backend.errors;

/**
   Print an error message, increasing the global error count
 */
nothrow:

extern (C++) void error(const(char)* filename, uint linnum, uint charnum, const(char)* format, ...);
