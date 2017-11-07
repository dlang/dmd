/**
 * Compiler implementation of the $(LINK2 http://www.dlang.org, D programming language)
 *
 * Copyright: Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/dmangle.d, _dmangle.d)
 */

module ddmd.dmangle;

// Online documentation: https://dlang.org/phobos/ddmd_dmangle.html

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.cppmangle;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.ctfloat;
import ddmd.root.outbuffer;
import ddmd.root.aav;
import ddmd.target;
import ddmd.tokens;
import ddmd.utf;
import ddmd.visitor;

private immutable char[TMAX] mangleChar =
[
    Tchar        : 'a',
    Tbool        : 'b',
    Tcomplex80   : 'c',
    Tfloat64     : 'd',
    Tfloat80     : 'e',
    Tfloat32     : 'f',
    Tint8        : 'g',
    Tuns8        : 'h',
    Tint32       : 'i',
    Timaginary80 : 'j',
    Tuns32       : 'k',
    Tint64       : 'l',
    Tuns64       : 'm',
    Tnone        : 'n',
    Tnull        : 'n', // yes, same as TypeNone
    Timaginary32 : 'o',
    Timaginary64 : 'p',
    Tcomplex32   : 'q',
    Tcomplex64   : 'r',
    Tint16       : 's',
    Tuns16       : 't',
    Twchar       : 'u',
    Tvoid        : 'v',
    Tdchar       : 'w',
    //              x   // const
    //              y   // immutable
    Tint128      : 'z', // zi
    Tuns128      : 'z', // zk

    Tarray       : 'A',
    Ttuple       : 'B',
    Tclass       : 'C',
    Tdelegate    : 'D',
    Tenum        : 'E',
    Tfunction    : 'F', // D function
    Tsarray      : 'G',
    Taarray      : 'H',
    Tident       : 'I',
    //              J   // out
    //              K   // ref
    //              L   // lazy
    //              M   // has this, or scope
    //              N   // Nh:vector Ng:wild
    //              O   // shared
    Tpointer     : 'P',
    //              Q   // Type/symbol/identifier backward reference
    Treference   : 'R',
    Tstruct      : 'S',
    //              T   // Ttypedef
    //              U   // C function
    //              V   // Pascal function
    //              W   // Windows function
    //              X   // variadic T t...)
    //              Y   // variadic T t,...)
    //              Z   // not variadic, end of parameters

    // '@' shouldn't appear anywhere in the deco'd names
    Tinstance    : '@',
    Terror       : '@',
    Ttypeof      : '@',
    Tslice       : '@',
    Treturn      : '@',
    Tvector      : '@',
];

unittest
{
    foreach (i, mangle; mangleChar)
    {
        if (mangle == char.init)
        {
            fprintf(stderr, "ty = %u\n", cast(uint)i);
            assert(0);
        }
    }
}

/***********************
 * Mangle basic type ty to buf.
 */

private void tyToDecoBuffer(OutBuffer* buf, int ty)
{
    const c = mangleChar[ty];
    buf.writeByte(c);
    if (c == 'z')
        buf.writeByte(ty == Tint128 ? 'i' : 'k');
}

/*********************************
 * Mangling for mod.
 */
private void MODtoDecoBuffer(OutBuffer* buf, MOD mod)
{
    switch (mod)
    {
    case 0:
        break;
    case MODconst:
        buf.writeByte('x');
        break;
    case MODimmutable:
        buf.writeByte('y');
        break;
    case MODshared:
        buf.writeByte('O');
        break;
    case MODshared | MODconst:
        buf.writestring("Ox");
        break;
    case MODwild:
        buf.writestring("Ng");
        break;
    case MODwildconst:
        buf.writestring("Ngx");
        break;
    case MODshared | MODwild:
        buf.writestring("ONg");
        break;
    case MODshared | MODwildconst:
        buf.writestring("ONgx");
        break;
    default:
        assert(0);
    }
}

extern (C++) final class Mangler : Visitor
{
    alias visit = super.visit;
public:
    static assert(Key.sizeof == size_t.sizeof);
    AA* types;
    AA* idents;
    OutBuffer* buf;

    extern (D) this(OutBuffer* buf)
    {
        this.buf = buf;
    }

    /**
    * writes a back reference with the relative position encoded with base 26
    *  using upper case letters for all digits but the last digit which uses
    *  a lower case letter.
    * The decoder has to look up the referenced position to determine
    *  whether the back reference is an identifer (starts with a digit)
    *  or a type (starts with a letter).
    *
    * Params:
    *  pos           = relative position to encode
    */
    final void writeBackRef(size_t pos)
    {
        buf.writeByte('Q');
        enum base = 26;
        size_t mul = 1;
        while (pos >= mul * base)
            mul *= base;
        while (mul >= base)
        {
            auto dig = cast(ubyte)(pos / mul);
            buf.writeByte('A' + dig);
            pos -= dig * mul;
            mul /= base;
        }
        buf.writeByte('a' + cast(ubyte)pos);
    }

    /**
    * Back references a non-basic type
    *
    * The encoded mangling is
    *       'Q' <relative position of first occurrence of type>
    *
    * Params:
    *  t = the type to encode via back referencing
    *
    * Returns:
    *  true if the type was found. A back reference has been encoded.
    *  false if the type was not found. The current position is saved for later back references.
    */
    final bool backrefType(Type t)
    {
        if (!t.isTypeBasic())
        {
            auto p = cast(size_t*)dmd_aaGet(&types, cast(Key)t);
            if (*p)
            {
                writeBackRef(buf.offset - *p);
                return true;
            }
            *p = buf.offset;
        }
        return false;
    }

    /**
    * Back references a single identifier
    *
    * The encoded mangling is
    *       'Q' <relative position of first occurrence of type>
    *
    * Params:
    *  id = the identifier to encode via back referencing
    *
    * Returns:
    *  true if the identifier was found. A back reference has been encoded.
    *  false if the identifier was not found. The current position is saved for later back references.
    */
    final bool backrefIdentifier(Identifier id)
    {
        auto p = cast(size_t*)dmd_aaGet(&idents, cast(Key)id);
        if (*p)
        {
            writeBackRef(buf.offset - *p);
            return true;
        }
        *p = buf.offset;
        return false;
    }

    final void mangleSymbol(Dsymbol s)
    {
        s.accept(this);
    }

    final void mangleType(Type t)
    {
        if (!backrefType(t))
            t.accept(this);
    }

    final void mangleIdentifier(Identifier id, Dsymbol s)
    {
        if (!backrefIdentifier(id))
            toBuffer(id.toChars(), s);
    }

    ////////////////////////////////////////////////////////////////////////////
    /**************************************************
     * Type mangling
     */
    void visitWithMask(Type t, ubyte modMask)
    {
        if (modMask != t.mod)
        {
            MODtoDecoBuffer(buf, t.mod);
        }
        mangleType(t);
    }

    override void visit(Type t)
    {
        tyToDecoBuffer(buf, t.ty);
    }

    override void visit(TypeNext t)
    {
        visit(cast(Type)t);
        visitWithMask(t.next, t.mod);
    }

    override void visit(TypeVector t)
    {
        buf.writestring("Nh");
        visitWithMask(t.basetype, t.mod);
    }

    override void visit(TypeSArray t)
    {
        visit(cast(Type)t);
        if (t.dim)
            buf.printf("%u", cast(uint)t.dim.toInteger());
        if (t.next)
            visitWithMask(t.next, t.mod);
    }

    override void visit(TypeDArray t)
    {
        visit(cast(Type)t);
        if (t.next)
            visitWithMask(t.next, t.mod);
    }

    override void visit(TypeAArray t)
    {
        visit(cast(Type)t);
        visitWithMask(t.index, 0);
        visitWithMask(t.next, t.mod);
    }

    override void visit(TypeFunction t)
    {
        //printf("TypeFunction.toDecoBuffer() t = %p %s\n", t, t.toChars());
        //static int nest; if (++nest == 50) *(char*)0=0;
        mangleFuncType(t, t, t.mod, t.next);
    }

    void mangleFuncType(TypeFunction t, TypeFunction ta, ubyte modMask, Type tret)
    {
        //printf("mangleFuncType() %s\n", t.toChars());
        if (t.inuse && tret)
        {
            // printf("TypeFunction.mangleFuncType() t = %s inuse\n", t.toChars());
            t.inuse = 2; // flag error to caller
            return;
        }
        t.inuse++;
        if (modMask != t.mod)
            MODtoDecoBuffer(buf, t.mod);
        ubyte mc;
        switch (t.linkage)
        {
        case LINKd:
            mc = 'F';
            break;
        case LINKc:
            mc = 'U';
            break;
        case LINKwindows:
            mc = 'W';
            break;
        case LINKpascal:
            mc = 'V';
            break;
        case LINKcpp:
            mc = 'R';
            break;
        case LINKobjc:
            mc = 'Y';
            break;
        default:
            assert(0);
        }
        buf.writeByte(mc);
        if (ta.purity || ta.isnothrow || ta.isnogc || ta.isproperty || ta.isref || ta.trust || ta.isreturn || ta.isscope)
        {
            if (ta.purity)
                buf.writestring("Na");
            if (ta.isnothrow)
                buf.writestring("Nb");
            if (ta.isref)
                buf.writestring("Nc");
            if (ta.isproperty)
                buf.writestring("Nd");
            if (ta.isnogc)
                buf.writestring("Ni");
            if (ta.isreturn)
                buf.writestring("Nj");
            if (ta.isscope && !ta.isreturn && !ta.isscopeinferred)
                buf.writestring("Nl");
            switch (ta.trust)
            {
            case TRUSTtrusted:
                buf.writestring("Ne");
                break;
            case TRUSTsafe:
                buf.writestring("Nf");
                break;
            default:
                break;
            }
        }
        // Write argument types
        paramsToDecoBuffer(t.parameters);
        //if (buf.data[buf.offset - 1] == '@') assert(0);
        buf.writeByte('Z' - t.varargs); // mark end of arg list
        if (tret !is null)
            visitWithMask(tret, 0);
        t.inuse--;
    }

    override void visit(TypeIdentifier t)
    {
        visit(cast(Type)t);
        const(char)* name = t.ident.toChars();
        size_t len = strlen(name);
        buf.printf("%u%s", cast(uint)len, name);
    }

    override void visit(TypeEnum t)
    {
        visit(cast(Type)t);
        mangleSymbol(t.sym);
    }

    override void visit(TypeStruct t)
    {
        //printf("TypeStruct.toDecoBuffer('%s') = '%s'\n", t.toChars(), name);
        visit(cast(Type)t);
        mangleSymbol(t.sym);
    }

    override void visit(TypeClass t)
    {
        //printf("TypeClass.toDecoBuffer('%s' mod=%x) = '%s'\n", t.toChars(), mod, name);
        visit(cast(Type)t);
        mangleSymbol(t.sym);
    }

    override void visit(TypeTuple t)
    {
        //printf("TypeTuple.toDecoBuffer() t = %p, %s\n", t, t.toChars());
        visit(cast(Type)t);
        paramsToDecoBuffer(t.arguments);
        buf.writeByte('Z');
    }

    override void visit(TypeNull t)
    {
        visit(cast(Type)t);
    }

    ////////////////////////////////////////////////////////////////////////////
    void mangleDecl(Declaration sthis)
    {
        mangleParent(sthis);
        assert(sthis.ident);
        mangleIdentifier(sthis.ident, sthis);
        if (FuncDeclaration fd = sthis.isFuncDeclaration())
        {
            mangleFunc(fd, false);
        }
        else if (sthis.type)
        {
            visitWithMask(sthis.type, 0);
        }
        else
            assert(0);
    }

    void mangleParent(Dsymbol s)
    {
        Dsymbol p;
        if (TemplateInstance ti = s.isTemplateInstance())
            p = ti.isTemplateMixin() ? ti.parent : ti.tempdecl.parent;
        else
            p = s.parent;
        if (p)
        {
            mangleParent(p);
            auto ti = p.isTemplateInstance();
            if (ti && !ti.isTemplateMixin())
            {
                mangleTemplateInstance(ti);
            }
            else if (p.getIdent())
            {
                mangleIdentifier(p.ident, s);
                if (FuncDeclaration f = p.isFuncDeclaration())
                    mangleFunc(f, true);
            }
            else
                buf.writeByte('0');
        }
    }

    void mangleFunc(FuncDeclaration fd, bool inParent)
    {
        //printf("deco = '%s'\n", fd.type.deco ? fd.type.deco : "null");
        //printf("fd.type = %s\n", fd.type.toChars());
        if (fd.needThis() || fd.isNested())
            buf.writeByte('M');

        if (!fd.type || fd.type.ty == Terror)
        {
            // never should have gotten here, but could be the result of
            // failed speculative compilation
            buf.writestring("9__error__FZ");

            //printf("[%s] %s no type\n", fd.loc.toChars(), fd.toChars());
            //assert(0); // don't mangle function until semantic3 done.
        }
        else if (inParent)
        {
            TypeFunction tf = cast(TypeFunction)fd.type;
            TypeFunction tfo = cast(TypeFunction)fd.originalType;
            mangleFuncType(tf, tfo, 0, null);
        }
        else
        {
            visitWithMask(fd.type, 0);
        }
    }

    /************************************************************
     * Write length prefixed string to buf.
     */
    void toBuffer(const(char)* id, Dsymbol s)
    {
        size_t len = strlen(id);
        if (buf.offset + len >= 8 * 1024 * 1024) // 8 megs ought be enough for anyone
            s.error("excessive length %llu for symbol, possible recursive expansion?", buf.offset + len);
        else
        {
            buf.printf("%u", cast(uint)len);
            buf.write(id, len);
        }
    }

    static const(char)* externallyMangledIdentifier(Declaration d)
    {
        if (!d.parent || d.parent.isModule() || d.linkage == LINKcpp) // if at global scope
        {
            switch (d.linkage)
            {
                case LINKd:
                    break;
                case LINKc:
                case LINKwindows:
                case LINKpascal:
                case LINKobjc:
                    return d.ident.toChars();
                case LINKcpp:
                    return Target.toCppMangle(d);
                case LINKdefault:
                    d.error("forward declaration");
                    return d.ident.toChars();
                default:
                    fprintf(stderr, "'%s', linkage = %d\n", d.toChars(), d.linkage);
                    assert(0);
            }
        }
        return null;
    }

    override void visit(Declaration d)
    {
        //printf("Declaration.mangle(this = %p, '%s', parent = '%s', linkage = %d)\n",
        //        d, d.toChars(), d.parent ? d.parent.toChars() : "null", d.linkage);
        if (auto id = externallyMangledIdentifier(d))
        {
            buf.writestring(id);
            return;
        }
        buf.writestring("_D");
        mangleDecl(d);
        debug
        {
            const slice = buf.peekSlice();
            assert(slice.length);
            foreach (const char c; slice)
            {
                assert(c == '_' || c == '@' || c == '?' || c == '$' || isalnum(c) || c & 0x80);
            }
        }
    }

    /******************************************************************************
     * Normally FuncDeclaration and FuncAliasDeclaration have overloads.
     * If and only if there is no overloads, mangle() could return
     * exact mangled name.
     *
     *      module test;
     *      void foo(long) {}           // _D4test3fooFlZv
     *      void foo(string) {}         // _D4test3fooFAyaZv
     *
     *      // from FuncDeclaration.mangle().
     *      pragma(msg, foo.mangleof);  // prints unexact mangled name "4test3foo"
     *                                  // by calling Dsymbol.mangle()
     *
     *      // from FuncAliasDeclaration.mangle()
     *      pragma(msg, __traits(getOverloads, test, "foo")[0].mangleof);  // "_D4test3fooFlZv"
     *      pragma(msg, __traits(getOverloads, test, "foo")[1].mangleof);  // "_D4test3fooFAyaZv"
     *
     * If a function has no overloads, .mangleof property still returns exact mangled name.
     *
     *      void bar() {}
     *      pragma(msg, bar.mangleof);  // still prints "_D4test3barFZv"
     *                                  // by calling FuncDeclaration.mangleExact().
     */
    override void visit(FuncDeclaration fd)
    {
        if (fd.isUnique())
            mangleExact(fd);
        else
            visit(cast(Dsymbol)fd);
    }

    // ditto
    override void visit(FuncAliasDeclaration fd)
    {
        FuncDeclaration f = fd.toAliasFunc();
        FuncAliasDeclaration fa = f.isFuncAliasDeclaration();
        if (!fd.hasOverloads && !fa)
        {
            mangleExact(f);
            return;
        }
        if (fa)
        {
            mangleSymbol(fa);
            return;
        }
        visit(cast(Dsymbol)fd);
    }

    override void visit(OverDeclaration od)
    {
        if (od.overnext)
        {
            visit(cast(Dsymbol)od);
            return;
        }
        if (FuncDeclaration fd = od.aliassym.isFuncDeclaration())
        {
            if (!od.hasOverloads || fd.isUnique())
            {
                mangleExact(fd);
                return;
            }
        }
        if (TemplateDeclaration td = od.aliassym.isTemplateDeclaration())
        {
            if (!od.hasOverloads || td.overnext is null)
            {
                mangleSymbol(td);
                return;
            }
        }
        visit(cast(Dsymbol)od);
    }

    void mangleExact(FuncDeclaration fd)
    {
        assert(!fd.isFuncAliasDeclaration());
        if (fd.mangleOverride)
        {
            buf.writestring(fd.mangleOverride);
            return;
        }
        if (fd.isMain())
        {
            buf.writestring("_Dmain");
            return;
        }
        if (fd.isWinMain() || fd.isDllMain() || fd.ident == Id.tls_get_addr)
        {
            buf.writestring(fd.ident.toChars());
            return;
        }
        visit(cast(Declaration)fd);
    }

    override void visit(VarDeclaration vd)
    {
        if (vd.mangleOverride)
        {
            buf.writestring(vd.mangleOverride);
            return;
        }
        visit(cast(Declaration)vd);
    }

    override void visit(AggregateDeclaration ad)
    {
        ClassDeclaration cd = ad.isClassDeclaration();
        Dsymbol parentsave = ad.parent;
        if (cd)
        {
            /* These are reserved to the compiler, so keep simple
             * names for them.
             */
            if (cd.ident == Id.Exception && cd.parent.ident == Id.object || cd.ident == Id.TypeInfo || cd.ident == Id.TypeInfo_Struct || cd.ident == Id.TypeInfo_Class || cd.ident == Id.TypeInfo_Tuple || cd == ClassDeclaration.object || cd == Type.typeinfoclass || cd == Module.moduleinfo || strncmp(cd.ident.toChars(), "TypeInfo_", 9) == 0)
            {
                // Don't mangle parent
                ad.parent = null;
            }
        }
        visit(cast(Dsymbol)ad);
        ad.parent = parentsave;
    }

    override void visit(TemplateInstance ti)
    {
        version (none)
        {
            printf("TemplateInstance.mangle() %p %s", ti, ti.toChars());
            if (ti.parent)
                printf("  parent = %s %s", ti.parent.kind(), ti.parent.toChars());
            printf("\n");
        }
        if (!ti.tempdecl)
            ti.error("is not defined");
        else
            mangleParent(ti);

        if (ti.isTemplateMixin() && ti.ident)
            mangleIdentifier(ti.ident, ti);
        else
            mangleTemplateInstance(ti);
    }

    final void mangleTemplateInstance(TemplateInstance ti)
    {
        TemplateDeclaration tempdecl = ti.tempdecl.isTemplateDeclaration();
        assert(tempdecl);

        // Use "__U" for the symbols declared inside template constraint.
        const char T = ti.members ? 'T' : 'U';
        buf.printf("__%c", T);
        mangleIdentifier(tempdecl.ident, tempdecl);

        auto args = ti.tiargs;
        size_t nparams = tempdecl.parameters.dim - (tempdecl.isVariadic() ? 1 : 0);
        for (size_t i = 0; i < args.dim; i++)
        {
            auto o = (*args)[i];
            Type ta = isType(o);
            Expression ea = isExpression(o);
            Dsymbol sa = isDsymbol(o);
            Tuple va = isTuple(o);
            //printf("\to [%d] %p ta %p ea %p sa %p va %p\n", i, o, ta, ea, sa, va);
            if (i < nparams && (*tempdecl.parameters)[i].specialization())
                buf.writeByte('H'); // https://issues.dlang.org/show_bug.cgi?id=6574
            if (ta)
            {
                buf.writeByte('T');
                visitWithMask(ta, 0);
            }
            else if (ea)
            {
                // Don't interpret it yet, it might actually be an alias template parameter.
                // Only constfold manifest constants, not const/immutable lvalues, see https://issues.dlang.org/show_bug.cgi?id=17339.
                enum keepLvalue = true;
                ea = ea.optimize(WANTvalue, keepLvalue);
                if (ea.op == TOKvar)
                {
                    sa = (cast(VarExp)ea).var;
                    ea = null;
                    goto Lsa;
                }
                if (ea.op == TOKthis)
                {
                    sa = (cast(ThisExp)ea).var;
                    ea = null;
                    goto Lsa;
                }
                if (ea.op == TOKfunction)
                {
                    if ((cast(FuncExp)ea).td)
                        sa = (cast(FuncExp)ea).td;
                    else
                        sa = (cast(FuncExp)ea).fd;
                    ea = null;
                    goto Lsa;
                }
                buf.writeByte('V');
                if (ea.op == TOKtuple)
                {
                    ea.error("tuple is not a valid template value argument");
                    continue;
                }
                // Now that we know it is not an alias, we MUST obtain a value
                uint olderr = global.errors;
                ea = ea.ctfeInterpret();
                if (ea.op == TOKerror || olderr != global.errors)
                    continue;

                /* Use type mangling that matches what it would be for a function parameter
                */
                visitWithMask(ea.type, 0);
                ea.accept(this);
            }
            else if (sa)
            {
            Lsa:
                sa = sa.toAlias();
                if (Declaration d = sa.isDeclaration())
                {
                    if (auto fad = d.isFuncAliasDeclaration())
                        d = fad.toAliasFunc();
                    if (d.mangleOverride)
                    {
                        buf.writeByte('X');
                        toBuffer(d.mangleOverride, d);
                        continue;
                    }
                    if (auto id = externallyMangledIdentifier(d))
                    {
                        buf.writeByte('X');
                        toBuffer(id, d);
                        continue;
                    }
                    if (!d.type || !d.type.deco)
                    {
                        ti.error("forward reference of %s %s", d.kind(), d.toChars());
                        continue;
                    }
                }
                buf.writeByte('S');
                mangleSymbol(sa);
            }
            else if (va)
            {
                assert(i + 1 == args.dim); // must be last one
                args = &va.objects;
                i = -cast(size_t)1;
            }
            else
                assert(0);
        }
        buf.writeByte('Z');
    }

    override void visit(Dsymbol s)
    {
        version (none)
        {
            printf("Dsymbol.mangle() '%s'", s.toChars());
            if (s.parent)
                printf("  parent = %s %s", s.parent.kind(), s.parent.toChars());
            printf("\n");
        }
        mangleParent(s);
        if (s.ident)
            mangleIdentifier(s.ident, s);
        else
            toBuffer(s.toChars(), s);
        //printf("Dsymbol.mangle() %s = %s\n", s.toChars(), id);
    }

    ////////////////////////////////////////////////////////////////////////////
    override void visit(Expression e)
    {
        e.error("expression %s is not a valid template value argument", e.toChars());
    }

    override void visit(IntegerExp e)
    {
        if (cast(sinteger_t)e.value < 0)
            buf.printf("N%lld", -e.value);
        else
            buf.printf("i%lld", e.value);
    }

    override void visit(RealExp e)
    {
        buf.writeByte('e');
        realToMangleBuffer(e.value);
    }

    void realToMangleBuffer(real_t value)
    {
        /* Rely on %A to get portable mangling.
         * Must munge result to get only identifier characters.
         *
         * Possible values from %A  => mangled result
         * NAN                      => NAN
         * -INF                     => NINF
         * INF                      => INF
         * -0X1.1BC18BA997B95P+79   => N11BC18BA997B95P79
         * 0X1.9P+2                 => 19P2
         */
        if (CTFloat.isNaN(value))
            buf.writestring("NAN"); // no -NAN bugs
        else if (CTFloat.isInfinity(value))
            buf.writestring(value < CTFloat.zero ? "NINF" : "INF");
        else
        {
            enum BUFFER_LEN = 36;
            char[BUFFER_LEN] buffer;
            const n = CTFloat.sprint(buffer.ptr, 'A', value);
            assert(n < BUFFER_LEN);
            for (int i = 0; i < n; i++)
            {
                char c = buffer[i];
                switch (c)
                {
                case '-':
                    buf.writeByte('N');
                    break;
                case '+':
                case 'X':
                case '.':
                    break;
                case '0':
                    if (i < 2)
                        break; // skip leading 0X
                    goto default;
                default:
                    buf.writeByte(c);
                    break;
                }
            }
        }
    }

    override void visit(ComplexExp e)
    {
        buf.writeByte('c');
        realToMangleBuffer(e.toReal());
        buf.writeByte('c'); // separate the two
        realToMangleBuffer(e.toImaginary());
    }

    override void visit(NullExp e)
    {
        buf.writeByte('n');
    }

    override void visit(StringExp e)
    {
        char m;
        OutBuffer tmp;
        const(char)[] q;
        /* Write string in UTF-8 format
         */
        switch (e.sz)
        {
        case 1:
            m = 'a';
            q = e.string[0 .. e.len];
            break;
        case 2:
            m = 'w';
            for (size_t u = 0; u < e.len;)
            {
                dchar c;
                const p = utf_decodeWchar(e.wstring, e.len, u, c);
                if (p)
                    e.error("%s", p);
                else
                    tmp.writeUTF8(c);
            }
            q = tmp.peekSlice();
            break;
        case 4:
            m = 'd';
            for (size_t u = 0; u < e.len; u++)
            {
                uint c = (cast(uint*)e.string)[u];
                if (!utf_isValidDchar(c))
                    e.error("invalid UCS-32 char \\U%08x", c);
                else
                    tmp.writeUTF8(c);
            }
            q = tmp.peekSlice();
            break;
        default:
            assert(0);
        }
        buf.reserve(1 + 11 + 2 * q.length);
        buf.writeByte(m);
        buf.printf("%d_", cast(int)q.length); // nbytes <= 11
        size_t qi = 0;
        for (char* p = cast(char*)buf.data + buf.offset, pend = p + 2 * q.length; p < pend; p += 2, ++qi)
        {
            char hi = (q[qi] >> 4) & 0xF;
            p[0] = cast(char)(hi < 10 ? hi + '0' : hi - 10 + 'a');
            char lo = q[qi] & 0xF;
            p[1] = cast(char)(lo < 10 ? lo + '0' : lo - 10 + 'a');
        }
        buf.offset += 2 * q.length;
    }

    override void visit(ArrayLiteralExp e)
    {
        size_t dim = e.elements ? e.elements.dim : 0;
        buf.printf("A%u", cast(uint)dim);
        for (size_t i = 0; i < dim; i++)
        {
            e.getElement(i).accept(this);
        }
    }

    override void visit(AssocArrayLiteralExp e)
    {
        size_t dim = e.keys.dim;
        buf.printf("A%u", cast(uint)dim);
        for (size_t i = 0; i < dim; i++)
        {
            (*e.keys)[i].accept(this);
            (*e.values)[i].accept(this);
        }
    }

    override void visit(StructLiteralExp e)
    {
        size_t dim = e.elements ? e.elements.dim : 0;
        buf.printf("S%u", cast(uint)dim);
        for (size_t i = 0; i < dim; i++)
        {
            Expression ex = (*e.elements)[i];
            if (ex)
                ex.accept(this);
            else
                buf.writeByte('v'); // 'v' for void
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    void paramsToDecoBuffer(Parameters* parameters)
    {
        //printf("Parameter.paramsToDecoBuffer()\n");

        int paramsToDecoBufferDg(size_t n, Parameter p)
        {
            p.accept(this);
            return 0;
        }

        Parameter._foreach(parameters, &paramsToDecoBufferDg);
    }

    override void visit(Parameter p)
    {
        if (p.storageClass & STCscope && !(p.storageClass & STCscopeinferred))
            buf.writeByte('M');
        // 'return inout ref' is the same as 'inout ref'
        if ((p.storageClass & (STCreturn | STCwild)) == STCreturn)
            buf.writestring("Nk");
        switch (p.storageClass & (STCin | STCout | STCref | STClazy))
        {
        case 0:
        case STCin:
            break;
        case STCout:
            buf.writeByte('J');
            break;
        case STCref:
            buf.writeByte('K');
            break;
        case STClazy:
            buf.writeByte('L');
            break;
        default:
            debug
            {
                printf("storageClass = x%llx\n", p.storageClass & (STCin | STCout | STCref | STClazy));
            }
            assert(0);
        }
        visitWithMask(p.type, 0);
    }
}


/******************************************************************************
 * Returns exact mangled name of function.
 */
extern (C++) const(char)* mangleExact(FuncDeclaration fd)
{
    if (!fd.mangleString)
    {
        OutBuffer buf;
        scope Mangler v = new Mangler(&buf);
        v.mangleExact(fd);
        fd.mangleString = buf.extractString();
    }
    return fd.mangleString;
}

extern (C++) void mangleToBuffer(Type t, OutBuffer* buf)
{
    if (t.deco)
        buf.writestring(t.deco);
    else
    {
        scope Mangler v = new Mangler(buf);
        v.visitWithMask(t, 0);
    }
}

extern (C++) void mangleToBuffer(Expression e, OutBuffer* buf)
{
    scope Mangler v = new Mangler(buf);
    e.accept(v);
}

extern (C++) void mangleToBuffer(Dsymbol s, OutBuffer* buf)
{
    scope Mangler v = new Mangler(buf);
    s.accept(v);
}

extern (C++) void mangleToBuffer(TemplateInstance ti, OutBuffer* buf)
{
    scope Mangler v = new Mangler(buf);
    v.mangleTemplateInstance(ti);
}

