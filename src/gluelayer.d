// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.gluelayer;

import ddmd.aggregate;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.expression;
import ddmd.lib;
import ddmd.mtype;
import ddmd.statement;
import ddmd.root.file;

version (NoBackend)
{
    struct Symbol;
    struct code;
    struct block;
    struct Blockx;
    struct elem;
    struct TYPE;
    alias type = TYPE;

    // tocsym

    extern (C++) Symbol* toInitializer(AggregateDeclaration ad)
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

    // iasm

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

    version (OSX)
    {
        extern(C++) void objc_initSymbols()
        {
        }
    }
}
else
{
    import ddmd.backend;

    alias Symbol = ddmd.backend.Symbol;
    alias code = ddmd.backend.code;
    alias block = ddmd.backend.block;
    alias Blockx = ddmd.backend.Blockx;
    alias elem = ddmd.backend.elem;
    alias type = ddmd.backend.type;

    extern extern (C++) Symbol* toInitializer(AggregateDeclaration sd);

    extern extern (C++) void obj_write_deferred(Library library);
    extern extern (C++) void obj_start(char* srcfile);
    extern extern (C++) void obj_end(Library library, File* objfile);
    extern extern (C++) void genObjFile(Module m, bool multiobj);

    extern extern (C++) void backend_init();
    extern extern (C++) void backend_term();

    extern extern (C++) Statement asmSemantic(AsmStatement s, Scope* sc);

    extern extern (C++) RET retStyle(TypeFunction tf);
    extern extern (C++) void toObjFile(Dsymbol ds, bool multiobj);

    version (OSX)
    {
        extern(C++) void objc_initSymbols();
    }
}
