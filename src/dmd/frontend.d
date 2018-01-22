/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * This module contains high-level interfaces for interacting
  with DMD as a library.
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/id.d, _id.d)
 * Documentation:  https://dlang.org/phobos/dmd_frontend.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/frontend.d
 */
module dmd.frontend;

/**
Initializes the DMD compiler
*/
void initDMD()
{
    import dmd.dmodule : Module;
    import dmd.globals : global;
    import dmd.id : Id;
    import dmd.mtype : Type;
    import dmd.target : Target;
    import dmd.expression : Expression;
    import dmd.objc : Objc;
    import dmd.builtin : builtin_init;
    import dmd.compiler : addDefaultVersionIdentifiers, printPredefinedVersions;

    global._init;
    addDefaultVersionIdentifiers();
    printPredefinedVersions();
    Type._init();
    Id.initialize();
    Module._init();
    Target._init();
    Expression._init();
    Objc._init();
    builtin_init();
}
