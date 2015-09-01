// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dmangle;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.cppmangle;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.mtype;
import ddmd.root.longdouble;
import ddmd.root.outbuffer;
import ddmd.root.port;
import ddmd.utf;
import ddmd.visitor;

extern (C++) __gshared const(char)*[TMAX] mangleChar =
[
    Tarray : "A",
    Tsarray : "G",
    Taarray : "H",
    Tpointer : "P",
    Treference : "R",
    Tfunction : "F",
    Tident : "I",
    Tclass : "C",
    Tstruct : "S",
    Tenum : "E",
    Tdelegate : "D",
    Tnone : "n",
    Tvoid : "v",
    Tint8 : "g",
    Tuns8 : "h",
    Tint16 : "s",
    Tuns16 : "t",
    Tint32 : "i",
    Tuns32 : "k",
    Tint64 : "l",
    Tuns64 : "m",
    Tint128 : "zi",
    Tuns128 : "zk",
    Tfloat32 : "f",
    Tfloat64 : "d",
    Tfloat80 : "e",
    Timaginary32 : "o",
    Timaginary64 : "p",
    Timaginary80 : "j",
    Tcomplex32 : "q",
    Tcomplex64 : "r",
    Tcomplex80 : "c",
    Tbool : "b",
    Tchar : "a",
    Twchar : "u",
    Tdchar : "w",
    // '@' shouldn't appear anywhere in the deco'd names
    Tinstance : "@",
    Terror : "@",
    Ttypeof : "@",
    Ttuple : "B",
    Tslice : "@",
    Treturn : "@",
    Tvector : "@",
    Tnull : "n", // same as TypeNone
];

unittest
{
    foreach (i, mangle; mangleChar)
    {
        if (!mangle)
            fprintf(stderr, "ty = %llu\n", cast(ulong)i);
        assert(mangle);
    }
}

/*********************************
 * Mangling for mod.
 */
extern (C++) void MODtoDecoBuffer(OutBuffer* buf, MOD mod)
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
    OutBuffer* buf;

    extern (D) this(OutBuffer* buf)
    {
        this.buf = buf;
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
        t.accept(this);
    }

    override void visit(Type t)
    {
        buf.writestring(mangleChar[t.ty]);
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
            buf.printf("%llu", t.dim.toInteger());
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
        //printf("TypeFunction::toDecoBuffer() t = %p %s\n", t, t->toChars());
        //static int nest; if (++nest == 50) *(char*)0=0;
        mangleFuncType(t, t, t.mod, t.next);
    }

    void mangleFuncType(TypeFunction t, TypeFunction ta, ubyte modMask, Type tret)
    {
        //printf("mangleFuncType() %s\n", t->toChars());
        if (t.inuse)
        {
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
        if (ta.purity || ta.isnothrow || ta.isnogc || ta.isproperty || ta.isref || ta.trust || ta.isreturn)
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
        //if (buf->data[buf->offset - 1] == '@') assert(0);
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
        t.sym.accept(this);
    }

    override void visit(TypeStruct t)
    {
        //printf("TypeStruct::toDecoBuffer('%s') = '%s'\n", t->toChars(), name);
        visit(cast(Type)t);
        t.sym.accept(this);
    }

    override void visit(TypeClass t)
    {
        //printf("TypeClass::toDecoBuffer('%s' mod=%x) = '%s'\n", t->toChars(), mod, name);
        visit(cast(Type)t);
        t.sym.accept(this);
    }

    override void visit(TypeTuple t)
    {
        //printf("TypeTuple::toDecoBuffer() t = %p, %s\n", t, t->toChars());
        visit(cast(Type)t);
        OutBuffer buf2;
        buf2.reserve(32);
        scope Mangler v = new Mangler(&buf2);
        v.paramsToDecoBuffer(t.arguments);
        int len = cast(int)buf2.offset;
        buf.printf("%d%.*s", len, len, buf2.extractData());
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
        const(char)* id = sthis.ident.toChars();
        toBuffer(id, sthis);
        if (FuncDeclaration fd = sthis.isFuncDeclaration())
        {
            mangleFunc(fd, false);
        }
        else if (sthis.type.deco)
        {
            buf.writestring(sthis.type.deco);
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
            if (p.getIdent())
            {
                const(char)* id = p.ident.toChars();
                toBuffer(id, s);
                if (FuncDeclaration f = p.isFuncDeclaration())
                    mangleFunc(f, true);
            }
            else
                buf.writeByte('0');
        }
    }

    void mangleFunc(FuncDeclaration fd, bool inParent)
    {
        //printf("deco = '%s'\n", fd->type->deco ? fd->type->deco : "null");
        //printf("fd->type = %s\n", fd->type->toChars());
        if (fd.needThis() || fd.isNested())
            buf.writeByte(Type.needThisPrefix());
        if (inParent)
        {
            TypeFunction tf = cast(TypeFunction)fd.type;
            TypeFunction tfo = cast(TypeFunction)fd.originalType;
            mangleFuncType(tf, tfo, 0, null);
        }
        else if (fd.type.deco)
        {
            buf.writestring(fd.type.deco);
        }
        else
        {
            printf("[%s] %s %s\n", fd.loc.toChars(), fd.toChars(), fd.type.toChars());
            assert(0); // don't mangle function until semantic3 done.
        }
    }

    /************************************************************
     * Write length prefixed string to buf.
     */
    void toBuffer(const(char)* id, Dsymbol s)
    {
        size_t len = strlen(id);
        if (len >= 8 * 1024 * 1024) // 8 megs ought be enough for anyone
            s.error("excessive length %llu for symbol, possible recursive expansion?", len);
        else
        {
            buf.printf("%llu", cast(ulong)len);
            buf.write(id, len);
        }
    }

    override void visit(Declaration d)
    {
        //printf("Declaration::mangle(this = %p, '%s', parent = '%s', linkage = %d)\n",
        //        d, d->toChars(), d->parent ? d->parent->toChars() : "null", d->linkage);
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
                buf.writestring(d.ident.toChars());
                return;
            case LINKcpp:
                buf.writestring(toCppMangle(d));
                return;
            case LINKdefault:
                d.error("forward declaration");
                buf.writestring(d.ident.toChars());
                return;
            default:
                fprintf(stderr, "'%s', linkage = %d\n", d.toChars(), d.linkage);
                assert(0);
            }
        }
        buf.writestring("_D");
        mangleDecl(d);
        debug
        {
            assert(buf.data);
            size_t len = buf.offset;
            assert(len > 0);
            for (size_t i = 0; i < len; i++)
            {
                assert(buf.data[i] == '_' || buf.data[i] == '@' || buf.data[i] == '?' || buf.data[i] == '$' || isalnum(buf.data[i]) || buf.data[i] & 0x80);
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
     *      // from FuncDeclaration::mangle().
     *      pragma(msg, foo.mangleof);  // prints unexact mangled name "4test3foo"
     *                                  // by calling Dsymbol::mangle()
     *
     *      // from FuncAliasDeclaration::mangle()
     *      pragma(msg, __traits(getOverloads, test, "foo")[0].mangleof);  // "_D4test3fooFlZv"
     *      pragma(msg, __traits(getOverloads, test, "foo")[1].mangleof);  // "_D4test3fooFAyaZv"
     *
     * If a function has no overloads, .mangleof property still returns exact mangled name.
     *
     *      void bar() {}
     *      pragma(msg, bar.mangleof);  // still prints "_D4test3barFZv"
     *                                  // by calling FuncDeclaration::mangleExact().
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
            fa.accept(this);
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
                td.accept(this);
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
            printf("TemplateInstance::mangle() %p %s", ti, ti.toChars());
            if (ti.parent)
                printf("  parent = %s %s", ti.parent.kind(), ti.parent.toChars());
            printf("\n");
        }
        if (!ti.tempdecl)
            ti.error("is not defined");
        else
            mangleParent(ti);
        ti.getIdent();
        const(char)* id = ti.ident ? ti.ident.toChars() : ti.toChars();
        toBuffer(id, ti);
        //printf("TemplateInstance::mangle() %s = %s\n", ti->toChars(), ti->id);
    }

    override void visit(Dsymbol s)
    {
        version (none)
        {
            printf("Dsymbol::mangle() '%s'", s.toChars());
            if (s.parent)
                printf("  parent = %s %s", s.parent.kind(), s.parent.toChars());
            printf("\n");
        }
        mangleParent(s);
        char* id = s.ident ? s.ident.toChars() : s.toChars();
        toBuffer(id, s);
        //printf("Dsymbol::mangle() %s = %s\n", s->toChars(), id);
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
        if (Port.isNan(value))
            buf.writestring("NAN"); // no -NAN bugs
        else if (Port.isInfinity(value))
            buf.writestring(value < 0 ? "NINF" : "INF");
        else
        {
            const(size_t) BUFFER_LEN = 36;
            char[BUFFER_LEN] buffer;
            size_t n = Port.ld_sprint(buffer.ptr, 'A', value);
            assert(n < BUFFER_LEN);
            for (size_t i = 0; i < n; i++)
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
                        break;
                    // skip leading 0X
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
        char* q;
        size_t qlen;
        /* Write string in UTF-8 format
         */
        switch (e.sz)
        {
        case 1:
            m = 'a';
            q = cast(char*)e.string;
            qlen = e.len;
            break;
        case 2:
            m = 'w';
            for (size_t u = 0; u < e.len;)
            {
                uint c;
                const(char)* p = utf_decodeWchar(cast(ushort*)e.string, e.len, &u, &c);
                if (p)
                    e.error("%s", p);
                else
                    tmp.writeUTF8(c);
            }
            q = cast(char*)tmp.data;
            qlen = tmp.offset;
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
            q = cast(char*)tmp.data;
            qlen = tmp.offset;
            break;
        default:
            assert(0);
        }
        buf.reserve(1 + 11 + 2 * qlen);
        buf.writeByte(m);
        buf.printf("%d_", cast(int)qlen); // nbytes <= 11
        for (char* p = cast(char*)buf.data + buf.offset, pend = p + 2 * qlen; p < pend; p += 2, ++q)
        {
            char hi = *q >> 4 & 0xF;
            p[0] = cast(char)(hi < 10 ? hi + '0' : hi - 10 + 'a');
            char lo = *q & 0xF;
            p[1] = cast(char)(lo < 10 ? lo + '0' : lo - 10 + 'a');
        }
        buf.offset += 2 * qlen;
    }

    override void visit(ArrayLiteralExp e)
    {
        size_t dim = e.elements ? e.elements.dim : 0;
        buf.printf("A%u", dim);
        for (size_t i = 0; i < dim; i++)
        {
            (*e.elements)[i].accept(this);
        }
    }

    override void visit(AssocArrayLiteralExp e)
    {
        size_t dim = e.keys.dim;
        buf.printf("A%u", dim);
        for (size_t i = 0; i < dim; i++)
        {
            (*e.keys)[i].accept(this);
            (*e.values)[i].accept(this);
        }
    }

    override void visit(StructLiteralExp e)
    {
        size_t dim = e.elements ? e.elements.dim : 0;
        buf.printf("S%u", dim);
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
        //printf("Parameter::paramsToDecoBuffer()\n");
        Parameter._foreach(parameters, &paramsToDecoBufferDg, cast(void*)this);
    }

    static int paramsToDecoBufferDg(void* ctx, size_t n, Parameter p)
    {
        p.accept(cast(Visitor)ctx);
        return 0;
    }

    override void visit(Parameter p)
    {
        if (p.storageClass & STCscope)
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

extern (C++) const(char)* mangle(Dsymbol s)
{
    OutBuffer buf;
    scope Mangler v = new Mangler(&buf);
    s.accept(v);
    return buf.extractString();
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
    scope Mangler v = new Mangler(buf);
    v.visitWithMask(t, 0);
}

extern (C++) void mangleToBuffer(Type t, OutBuffer* buf, bool internal)
{
    if (internal)
    {
        buf.writestring(mangleChar[t.ty]);
        if (t.ty == Tarray)
            buf.writestring(mangleChar[(cast(TypeArray)t).next.ty]);
    }
    else if (t.deco)
        buf.writestring(t.deco);
    else
        mangleToBuffer(t, buf);
}

extern (C++) void mangleToBuffer(Expression e, OutBuffer* buf)
{
    scope Mangler v = new Mangler(buf);
    e.accept(v);
}
