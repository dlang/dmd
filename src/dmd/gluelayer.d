/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/gluelayer.d, _gluelayer.d)
 */

module dmd.gluelayer;

// Online documentation: https://dlang.org/phobos/dmd_gluelayer.html

import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.mtype;
import dmd.statement;
import dmd.root.file;

version (NoBackend)
{
    import dmd.lib : Library;

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

        void objc_initSymbols() {}
    }
}
else
{
    import dmd.lib : Library;

    public import dmd.backend.cc : block, Blockx, Symbol;
    public import dmd.backend.type : type;
    public import dmd.backend.el : elem;
    public import dmd.backend.code : code;

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

        void objc_initSymbols();
    }
}
