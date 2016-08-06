/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _gluelayer.d)
 */

module ddmd.gluelayer;

import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
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
    import ddmd.backend.type;

    alias Symbol = ddmd.backend.type.Symbol;
    alias code = ddmd.backend.type.code;
    alias block = ddmd.backend.type.block;
    alias Blockx = ddmd.backend.type.Blockx;
    alias elem = ddmd.backend.type.elem;
    alias type = ddmd.backend.type.type;

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
