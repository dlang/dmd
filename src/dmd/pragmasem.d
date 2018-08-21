/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/pragmasem.d, _pragmasem.d)
 * Documentation:  https://dlang.org/phobos/dmd_pragmasem.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/pragmasem.d
 */

module dmd.pragmasem;

import core.stdc.stdio;
import core.stdc.string;

import dmd.arraytypes;
import dmd.attrib;
import dmd.cond;
import dmd.expression;
import dmd.expressionsem;
import dmd.errors;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.dmangle;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem;
import dmd.globals;
import dmd.id;
import dmd.identifier;
import dmd.mtype;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.statement : Statement, PragmaStatement, ErrorStatement;
import dmd.statementsem;
import dmd.tokens : TOK;
import dmd.dtemplate : getDsymbol;
import dmd.utf;
import dmd.utils;

/**
 * Semanically analyses a PragmaStatement.
 * Params:
 *  sc        = scope of evaluation
 *  ps        = PragmaStatement to analyse
 */
Statement pragmaSemantic(Scope* sc, PragmaStatement ps)
{
    auto psa = PragmaSemanticAnalysis(sc, ps, null);
    psa.semantic(ps.ident);
    return psa.result;
}

/**
 * Semanically analyses a PragmaDeclaration.
 * Params:
 *  sc        = scope of evaluation
 *  pd        = PragmaDeclaration to analyse
 */
void pragmaSemantic(Scope* sc, PragmaDeclaration pd)
{
    auto psa = PragmaSemanticAnalysis(sc, null, pd);
    psa.semantic(pd.ident);
}

private struct PragmaSemanticAnalysis
{
    Scope* sc;
    Expressions* args;
    PragmaStatement ps;
    PragmaDeclaration pd;
    Statement result;

    this(Scope* sc, PragmaStatement ps, PragmaDeclaration pd)
    {
        this.sc = sc;
        this.args = ps ? ps.args : pd.args;
        this.ps = ps;
        this.pd = pd;
    }

    private void setError()
    {
        if (ps)
            result = new ErrorStatement();
    }

    // Because auto p = ps ? ps : pd; p.error("foo"); does not compile
    private void error(const(char)* msg, const(char)* msg2 = null)
    {
        if (msg2)
        {
            if (ps)
                ps.error(msg, msg2);
            else
                pd.error(msg, msg2);
        }
        else
        {
            if (ps)
                ps.error(msg);
            else
                pd.error(msg);
        }
        setError();
    }

    void declSementic()
    {
        if (pd && pd.decl)
        {
            pd.error("is missing a terminating `;`");
            Scope* sc2 = pd.newScope(sc);
            foreach(s; *pd.decl)
            s.dsymbolSemantic(sc2);
            
            if (sc2 != sc)
            sc2.pop();
        }
    }
    void semantic(Identifier ident)
    {
        import dmd.target;
        
        if (ident == Id.msg)
            pragmaMsgSemantic();
        else if (ident == Id.lib)
            pragmaLibSemantic();
        else if (ident == Id.startaddress)
            pragmaStartAddressSemantic();
        else if (ident == Id.Pinline)
            pragmaInlineSemantic();
        else if (ident == Id.mangle)
            pragmaMangleSemantic(); // does semantic on its decls
        else if (ident == Id.crt_constructor || ident == Id.crt_destructor)
            pragmaCrtCtorDtorSemantic(ident);
        else if (global.params.ignoreUnsupportedPragmas && global.params.verbose)
        {
            /* Print unrecognized pragmas
             */
            OutBuffer buf;
            buf.writestring(pd.ident.toChars());
            bool first = true;
            foreach (e; *args)
            {
                sc = sc.startCTFE();
                e = e.expressionSemantic(sc);
                e = resolveProperties(sc, e);
                sc = sc.endCTFE();
                e = e.ctfeInterpret();
                if (first)
                {
                    buf.writestring(" (");
                    first = false;
                }
                else
                buf.writeByte(',');
                buf.writestring(e.toChars());
            }
            if (args.dim)
            buf.writeByte(')');
            message("pragma    %s", buf.peekString());
        }
        else
        {
            enum msg = "unrecognized `pragma(%s)`";
            if (ps)
                .error(ps.loc, msg, ps.ident.toChars());
            else
                .error(pd.loc, msg, pd.ident.toChars());
        }
    }

    // https://dlang.org/spec/pragma.html#msg
    void pragmaMsgSemantic()
    {
        if (!args)
            return;

        foreach (e; *args)
        {
            sc = sc.startCTFE();
            e = e.expressionSemantic(sc);
            e = resolveProperties(sc, e);
            sc = sc.endCTFE();
            // pragma(msg) is allowed to contain types as well as expressions
            if (e.type && e.type.ty == Tvoid)
            {
                .error(pd.loc, "Cannot pass argument `%s` to `pragma msg` because it is `void`", e.toChars());
                return;
            }
            e = ctfeInterpretForPragmaMsg(e);
            if (e.op == TOK.error)
            {
                errorSupplemental(pd.loc, "while evaluating `pragma(msg, %s)`", e.toChars());
                return;
            }
            StringExp se = e.toStringExp();
            if (se)
            {
                se = se.toUTF8(sc);
                fprintf(stderr, "%.*s", cast(int)se.len, se.string);
            }
            else
                fprintf(stderr, "%s", e.toChars());
        }
        fprintf(stderr, "\n");
        declSementic();
    }

    // https://dlang.org/spec/pragma.html#lib
    void pragmaLibSemantic()
    {
        
        /* Should this be allowed?
         */
        if (ps)
        {
            ps.error("`pragma(lib)` not allowed as statement");
            return;
        }
        
        if (!args || args.dim != 1)
            pd.error("string expected for library name");
        else
        {
            auto se = semanticString(sc, (*args)[0], "library name");
            if (!se)
            return;
            
            (*args)[0] = se;
            import dmd.root.rmem;
            auto name = cast(char*)mem.xmalloc(se.len + 1);
            memcpy(name, se.string, se.len);
            name[se.len] = 0;
            
            if (global.params.verbose)
            message("library   %s", name);
            
            if (global.params.moduleDeps && !global.params.moduleDepsFile)
            {
                OutBuffer* ob = global.params.moduleDeps;
                Module imod = sc.instantiatingModule();
                ob.writestring("depsLib ");
                ob.writestring(imod.toPrettyChars());
                ob.writestring(" (");
                escapePath(ob, imod.srcfile.toChars());
                ob.writestring(") : ");
                ob.writestring(name);
                ob.writenl();
            }
            mem.xfree(name);
        }
        declSementic();
    }

    // https://dlang.org/spec/pragma.html#startaddress
    void pragmaStartAddressSemantic()
    {
        if (!args || args.dim != 1)
        {
            return this.error("function name expected for start address");
        }
        /* https://issues.dlang.org/show_bug.cgi?id=11980
         * resolveProperties and ctfeInterpret call are not necessary.
         */
        Expression e = (*args)[0];
        sc = sc.startCTFE();
        e = e.expressionSemantic(sc);
        sc = sc.endCTFE();
        if (ps)
            e = e.ctfeInterpret();
        (*args)[0] = e;
        
        Dsymbol sa = getDsymbol(e);
        if (!sa || !sa.isFuncDeclaration())
        {
            return this.error("function name expected for start address, not `%s`", e.toChars());
        }
        if (ps && ps._body)
        {
            ps._body = ps._body.statementSemantic(sc);
            if (ps._body.isErrorStatement())
            {
                result = ps._body;
                return;
            }
        }
        result = ps;
        declSementic();
    }

    // https://dlang.org/spec/pragma.html#inline
    void pragmaInlineSemantic()
    {
        if (pd)
        {
            return;
        }

        PINLINE inlining = PINLINE.default_;
        if (!args || args.dim == 0)
            inlining = PINLINE.default_;
        else if (!args || args.dim != 1)
        {
            ps.error("boolean expression expected for `pragma(inline)`");
            return setError();
        }
        else
        {
            Expression e = (*ps.args)[0];
            if (e.op != TOK.int64 || !e.type.equals(Type.tbool))
            {
                ps.error("pragma(inline, true or false) expected, not `%s`", e.toChars());
                return setError();
            }

            if (e.isBool(true))
                inlining = PINLINE.always;
            else if (e.isBool(false))
                inlining = PINLINE.never;

            auto fd = sc.func;
            if (!fd)
            {
                ps.error("`pragma(inline)` is not inside a function");
                return setError();
            }

            fd.inlining = inlining;
        }
        declSementic();
    }

    // https://dlang.org/spec/pragma.html#mangle
    void pragmaMangleSemantic()
    {
        if (!args)
        {
            args = new Expressions(1);
            if (ps)
                ps.args = args;
            else
                pd.args = args;
            goto Largdim;
        }
        if (args.dim != 1)
        {
            Largdim:
            this.error("string expected for mangled name");
            args.setDim(1);
            (*args)[0] = new ErrorExp(); // error recovery
            return;
        }
        
        auto se = semanticString(sc, (*args)[0], "mangled name");
        if (!se)
        {
            return;
        }
        (*args)[0] = se; // Will be used later
        
        if (!se.len)
        {
            se.error("zero-length string not allowed for mangled name");
            return;
        }
        if (se.sz != 1)
        {
            se.error("mangled name characters can only be of type `char`");
            return;
        }
        version (all)
        {
            /* Note: D language specification should not have any assumption about backend
             * implementation. Ideally pragma(mangle) can accept a string of any content.
             *
             * Therefore, this validation is compiler implementation specific.
             */
            for (size_t i = 0; i < se.len;)
            {
                char* p = se.string;
                dchar c = p[i];
                if (c < 0x80)
                {
                    if (c.isValidMangling)
                    {
                        ++i;
                        continue;
                    }
                    else
                    {
                        se.error("char 0x%02x not allowed in mangled name", c);
                        break;
                    }
                }
                if (const msg = utf_decodeChar(se.string, se.len, i, c))
                {
                    se.error("%s", msg);
                    break;
                }
                if (!isUniAlpha(c))
                {
                    se.error("char `0x%04x` not allowed in mangled name", c);
                    break;
                }
            }
        }
        
        /*
         pragma(mangle, "aaa") __gshared int a = 1;   //PragmaDeclaration
         void main()
         {
            pragma(mangle, "bbb") __gshared int b = 1;   //PragaStatement
         }
         */
        if (pd)
        {
            Scope* sc2 = pd.newScope(sc);
            if(pd.decl.dim == 1)
            {
                Dsymbol s = (*pd.decl)[0];
                char* name = cast(char*)mem.xmalloc(se.len + 1);
                memcpy(name, se.string, se.len);
                name[se.len] = 0;
                uint cnt = setMangleOverride(s, name);
                if (cnt > 1)
                    pd.error("can only apply to a single declaration");
                s.dsymbolSemantic(sc2);
            }
            else
            {
                pd.error("can only apply to a single declaration");
                for (size_t i = 0; i < pd.decl.dim; i++)
                {
                    Dsymbol s = (*pd.decl)[i];
                    s.dsymbolSemantic(sc2);
                }
            }
            if (sc2 != sc)
                sc2.pop();
        }
        else
        {
            //FIXME: https://issues.dlang.org/show_bug.cgi?id=19149
            ps.error("can only be used as a PragmaDeclaration");
        }
    }
    
    void pragmaCrtCtorDtorSemantic(Identifier ident)
    {
        if (ps)
        {
            ps.error("`pragma(%s)` not allowed as statement", ident.toChars());
        }
        else if (args && args.dim != 0)
        {
            pd.error("takes no argument");
        }
        else if (sc.func && sc.func.vthis)
        {
            pd.error("cannot be used on nested functions");
        }
        declSementic();
    }
}

private uint setMangleOverride(Dsymbol s, char* sym)
{
    AttribDeclaration ad = s.isAttribDeclaration();
    if (ad)
    {
        Dsymbols* decls = ad.include(null);
        uint nestedCount = 0;
        if (decls && decls.dim)
            for (size_t i = 0; i < decls.dim; ++i)
                nestedCount += setMangleOverride((*decls)[i], sym);
        return nestedCount;
    }
    else if (s.isFuncDeclaration() || s.isVarDeclaration())
    {
        s.isDeclaration().mangleOverride = sym;
        return 1;
    }
    else
        return 0;
}
