// Compiler implementation of the D programming language
// Copyright (c) 1999-2016 by Digital Mars
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

    extern (C++)
    {
        // glue
        void obj_write_deferred(Library library)        {}
        void obj_start(char* srcfile)                   {}
        void obj_end(Library library, File* objfile)    {}
        void genObjFile(Module m, bool multiobj)        {}

        // msc
        void backend_init() {}
        void backend_term() {}

        // iasm
        Statement asmSemantic(AsmStatement s, Scope* sc) { assert(0); }

        // toir
        RET retStyle(TypeFunction tf)               { return RETregs; }
        void toObjFile(Dsymbol ds, bool multiobj)   {}

        version (OSX)
        {
            void objc_initSymbols() {}
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

    extern (C++)
    {
        void obj_write_deferred(Library library);
        void obj_start(char* srcfile);
        void obj_end(Library library, File* objfile);
        void genObjFile(Module m, bool multiobj);

        void backend_init();
        void backend_term();

        Statement asmSemantic(AsmStatement s, Scope* sc);

        RET retStyle(TypeFunction tf);
        void toObjFile(Dsymbol ds, bool multiobj);

        version (OSX)
        {
            void objc_initSymbols();
        }
    }
}
