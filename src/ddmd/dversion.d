/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _dversion.d)
 */

module ddmd.dversion;

import ddmd.arraytypes;
import ddmd.cond;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dsymbol;
import ddmd.globals;
import ddmd.identifier;
import ddmd.root.outbuffer;
import ddmd.visitor;

/***********************************************************
 * DebugSymbol's happen for statements like:
 *      debug = identifier;
 *      debug = integer;
 */
extern (C++) final class DebugSymbol : Dsymbol
{
    uint level;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(ident);
        this.loc = loc;
    }

    extern (D) this(Loc loc, uint level)
    {
        this.level = level;
        this.loc = loc;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ds = new DebugSymbol(loc, ident);
        ds.level = level;
        return ds;
    }

    override const(char)* toChars() const
    {
        if (ident)
            return ident.toChars();
        else
        {
            OutBuffer buf;
            buf.printf("%d", level);
            return buf.extractString();
        }
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        //printf("DebugSymbol::addMember('%s') %s\n", sds.toChars(), toChars());
        Module m = sds.isModule();
        // Do not add the member to the symbol table,
        // just make sure subsequent debug declarations work.
        if (ident)
        {
            if (!m)
            {
                error("declaration must be at module level");
                errors = true;
            }
            else
            {
                if (findCondition(m.debugidsNot, ident))
                {
                    error("defined after use");
                    errors = true;
                }
                if (!m.debugids)
                    m.debugids = new Strings();
                m.debugids.push(ident.toChars());
            }
        }
        else
        {
            if (!m)
            {
                error("level declaration must be at module level");
                errors = true;
            }
            else
                m.debuglevel = level;
        }
    }

    override void semantic(Scope* sc)
    {
        //printf("DebugSymbol::semantic() %s\n", toChars());
        if (semanticRun < PASSsemanticdone)
            semanticRun = PASSsemanticdone;
    }

    override const(char)* kind() const
    {
        return "debug";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * VersionSymbol's happen for statements like:
 *      version = identifier;
 *      version = integer;
 */
extern (C++) final class VersionSymbol : Dsymbol
{
    uint level;

    extern (D) this(Loc loc, Identifier ident)
    {
        super(ident);
        this.loc = loc;
    }

    extern (D) this(Loc loc, uint level)
    {
        this.level = level;
        this.loc = loc;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        auto ds = ident ? new VersionSymbol(loc, ident)
                        : new VersionSymbol(loc, level);
        return ds;
    }

    override const(char)* toChars()
    {
        if (ident)
            return ident.toChars();
        else
        {
            OutBuffer buf;
            buf.printf("%d", level);
            return buf.extractString();
        }
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        //printf("VersionSymbol::addMember('%s') %s\n", sds.toChars(), toChars());
        Module m = sds.isModule();
        // Do not add the member to the symbol table,
        // just make sure subsequent debug declarations work.
        if (ident)
        {
            VersionCondition.checkReserved(loc, ident.toString());
            if (!m)
            {
                error("declaration must be at module level");
                errors = true;
            }
            else
            {
                if (findCondition(m.versionidsNot, ident))
                {
                    error("defined after use");
                    errors = true;
                }
                if (!m.versionids)
                    m.versionids = new Strings();
                m.versionids.push(ident.toChars());
            }
        }
        else
        {
            if (!m)
            {
                error("level declaration must be at module level");
                errors = true;
            }
            else
                m.versionlevel = level;
        }
    }

    override void semantic(Scope* sc)
    {
        if (semanticRun < PASSsemanticdone)
            semanticRun = PASSsemanticdone;
    }

    override const(char)* kind() const
    {
        return "version";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
