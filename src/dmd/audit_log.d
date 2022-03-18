/**
 * Generate text files for assistance in frontend development.
 *
  * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     Alexander Heistermann
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/audit_log.d, _audit_log.d)
 * Documentation:  https://dlang.org/phobos/dmd_asttypename.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/audit_log.d
 */

module dmd.audit_log;
import core.stdc.stdlib;
import core.stdc.stdio;
import dmd.root.rootobject;
import dmd.globals;
import dmd.ast_node;
import dmd.hdrgen;
import dmd.expression;
import dmd.dsymbol;
import dmd.statement;
import dmd.mtype;
import dmd.init;
import dmd.dtemplate;
import dmd.common.outbuffer;

private FILE*[string] file;

void Log(ASTNode node, string functioncall = __FUNCTION__, string modulecall = __MODULE__)
{
    debug(__dmd_debug)
    {
        bool Exist()
        {
            auto paramCalls = global.params.calls;
                for (size_t i = 0; i < paramCalls.length; i++)
                {
                    if (global.params.calls[i].toString() == functioncall
                       || global.params.calls[i].toString() ==  modulecall)
                        return true;
                }
                return false;
        }
        if (!Exist())
            return;
        auto tmpstring = "debug/" ~ modulecall ~ "/" ~ functioncall ~ ".txt\0";
        auto tmpfile = file.require(modulecall ~ " " ~ functioncall, fopen(tmpstring.ptr, "w+\0".ptr));
        OutBuffer buf;
        HdrGenState hgs;
        static if (is(typeof(node) == Type))
            toCBuffer(node, &buf, node.getTypeInfoIdent(), &hgs);
        else
            toCBuffer(node, &buf, &hgs);
        fputs(buf.extractChars(), tmpfile);
    }
}

void closeAll()
{
    debug(__dmd_debug)
    {
        foreach (FILE* f; file)
        {
            fclose(f);
        }
    }
}
