/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/gluestub.c
 */

module ddmd.gluestub;

import ddmd.backend;
import ddmd.aggregate;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.lib;
import ddmd.mtype;
import ddmd.root.file;
import ddmd.statement;

// tocsym

extern (C++) Symbol* toInitializer(AggregateDeclaration ad)
{
    return null;
}

extern (C++) Symbol* toModuleAssert(Module m)
{
    return null;
}

extern (C++) Symbol* toModuleUnittest(Module m)
{
    return null;
}

extern (C++) Symbol* toModuleArray(Module m)
{
    return null;
}

// glue

extern (C++) void obj_write_deferred(Library library)
{
}

extern (C++) void obj_start(char* srcfile)
{
}

extern (C++) void obj_end(Library library, File* objfile)
{
}

extern (C++) void genObjFile(Module m, bool multiobj)
{
}

// msc

extern (C++) void backend_init()
{
}

extern (C++) void backend_term()
{
}

// lib

extern (C++) Library LibMSCoff_factory()
{
    assert(0);
}

extern (C++) Library LibElf_factory()
{
    assert(0);
}

extern (C++) Library LibMach_factory()
{
    assert(0);
}

extern (C++) Statement asmSemantic(AsmStatement s, Scope* sc)
{
    assert(0);
}

// toir

extern (C++) RET retStyle(TypeFunction tf)
{
    return RETregs;
}

extern (C++) void toObjFile(Dsymbol ds, bool multiobj)
{
}
