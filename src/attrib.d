// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.attrib;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.cond;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dinterpret;
import ddmd.dmodule;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.hdrgen;
import ddmd.id;
import ddmd.identifier;
import ddmd.mars;
import ddmd.mtype;
import ddmd.parse;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.tokens;
import ddmd.utf;
import ddmd.visitor;

/***********************************************************
 */
extern (C++) class AttribDeclaration : Dsymbol
{
public:
    Dsymbols* decl;     // array of Dsymbol's

    final extern (D) this(Dsymbols* decl)
    {
        this.decl = decl;
    }

    Dsymbols* include(Scope* sc, ScopeDsymbol sds)
    {
        return decl;
    }

    override final int apply(Dsymbol_apply_ft_t fp, void* param)
    {
        Dsymbols* d = include(_scope, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                if (s)
                {
                    if (s.apply(fp, param))
                        return 1;
                }
            }
        }
        return 0;
    }

    /****************************************
     * Create a new scope if one or more given attributes
     * are different from the sc's.
     * If the returned scope != sc, the caller should pop
     * the scope after it used.
     */
    final static Scope* createNewScope(Scope* sc, StorageClass stc, LINK linkage, Prot protection, int explicitProtection, structalign_t structalign, PINLINE inlining)
    {
        Scope* sc2 = sc;
        if (stc != sc.stc || linkage != sc.linkage || !protection.isSubsetOf(sc.protection) || explicitProtection != sc.explicitProtection || structalign != sc.structalign || inlining != sc.inlining)
        {
            // create new one for changes
            sc2 = sc.copy();
            sc2.stc = stc;
            sc2.linkage = linkage;
            sc2.protection = protection;
            sc2.explicitProtection = explicitProtection;
            sc2.structalign = structalign;
            sc2.inlining = inlining;
        }
        return sc2;
    }

    /****************************************
     * A hook point to supply scope for members.
     * addMember, setScope, importAll, semantic, semantic2 and semantic3 will use this.
     */
    Scope* newScope(Scope* sc)
    {
        return sc;
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        Dsymbols* d = include(sc, sds);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                //printf("\taddMember %s to %s\n", s->toChars(), sds->toChars());
                s.addMember(sc2, sds);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void setScope(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        //printf("\tAttribDeclaration::setScope '%s', d = %p\n",toChars(), d);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.setScope(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void importAll(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        //printf("\tAttribDeclaration::importAll '%s', d = %p\n", toChars(), d);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.importAll(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void semantic(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        //printf("\tAttribDeclaration::semantic '%s', d = %p\n",toChars(), d);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void semantic2(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic2(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void semantic3(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        if (d)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.semantic3(sc2);
            }
            if (sc2 != sc)
                sc2.pop();
        }
    }

    override void addComment(const(char)* comment)
    {
        //printf("AttribDeclaration::addComment %s\n", comment);
        if (comment)
        {
            Dsymbols* d = include(null, null);
            if (d)
            {
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    //printf("AttribDeclaration::addComment %s\n", s->toChars());
                    s.addComment(comment);
                }
            }
        }
    }

    override const(char)* kind()
    {
        return "attribute";
    }

    override bool oneMember(Dsymbol* ps, Identifier ident)
    {
        Dsymbols* d = include(null, null);
        return Dsymbol.oneMembers(d, ps, ident);
    }

    override void setFieldOffset(AggregateDeclaration ad, uint* poffset, bool isunion)
    {
        Dsymbols* d = include(null, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.setFieldOffset(ad, poffset, isunion);
            }
        }
    }

    override final bool hasPointers()
    {
        Dsymbols* d = include(null, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                if (s.hasPointers())
                    return true;
            }
        }
        return false;
    }

    override final bool hasStaticCtorOrDtor()
    {
        Dsymbols* d = include(null, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                if (s.hasStaticCtorOrDtor())
                    return true;
            }
        }
        return false;
    }

    override final void checkCtorConstInit()
    {
        Dsymbols* d = include(null, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.checkCtorConstInit();
            }
        }
    }

    /****************************************
     */
    override final void addLocalClass(ClassDeclarations* aclasses)
    {
        Dsymbols* d = include(null, null);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.addLocalClass(aclasses);
            }
        }
    }

    override final AttribDeclaration isAttribDeclaration()
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) class StorageClassDeclaration : AttribDeclaration
{
public:
    StorageClass stc;

    final extern (D) this(StorageClass stc, Dsymbols* decl)
    {
        super(decl);
        this.stc = stc;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new StorageClassDeclaration(stc, Dsymbol.arraySyntaxCopy(decl));
    }

    override final Scope* newScope(Scope* sc)
    {
        StorageClass scstc = sc.stc;
        /* These sets of storage classes are mutually exclusive,
         * so choose the innermost or most recent one.
         */
        if (stc & (STCauto | STCscope | STCstatic | STCextern | STCmanifest))
            scstc &= ~(STCauto | STCscope | STCstatic | STCextern | STCmanifest);
        if (stc & (STCauto | STCscope | STCstatic | STCtls | STCmanifest | STCgshared))
            scstc &= ~(STCauto | STCscope | STCstatic | STCtls | STCmanifest | STCgshared);
        if (stc & (STCconst | STCimmutable | STCmanifest))
            scstc &= ~(STCconst | STCimmutable | STCmanifest);
        if (stc & (STCgshared | STCshared | STCtls))
            scstc &= ~(STCgshared | STCshared | STCtls);
        if (stc & (STCsafe | STCtrusted | STCsystem))
            scstc &= ~(STCsafe | STCtrusted | STCsystem);
        scstc |= stc;
        //printf("scstc = x%llx\n", scstc);
        return createNewScope(sc, scstc, sc.linkage, sc.protection, sc.explicitProtection, sc.structalign, sc.inlining);
    }

    override final bool oneMember(Dsymbol* ps, Identifier ident)
    {
        bool t = Dsymbol.oneMembers(decl, ps, ident);
        if (t && *ps)
        {
            /* This is to deal with the following case:
             * struct Tick {
             *   template to(T) { const T to() { ... } }
             * }
             * For eponymous function templates, the 'const' needs to get attached to 'to'
             * before the semantic analysis of 'to', so that template overloading based on the
             * 'this' pointer can be successful.
             */
            FuncDeclaration fd = (*ps).isFuncDeclaration();
            if (fd)
            {
                /* Use storage_class2 instead of storage_class otherwise when we do .di generation
                 * we'll wind up with 'const const' rather than 'const'.
                 */
                /* Don't think we need to worry about mutually exclusive storage classes here
                 */
                fd.storage_class2 |= stc;
            }
        }
        return t;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class DeprecatedDeclaration : StorageClassDeclaration
{
public:
    Expression msg;

    extern (D) this(Expression msg, Dsymbols* decl)
    {
        super(STCdeprecated, decl);
        this.msg = msg;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new DeprecatedDeclaration(msg.syntaxCopy(), Dsymbol.arraySyntaxCopy(decl));
    }

    override void setScope(Scope* sc)
    {
        assert(msg);
        char* depmsg = null;
        StringExp se = msg.toStringExp();
        if (se)
            depmsg = cast(char*)se.string;
        else
            msg.error("string expected, not '%s'", msg.toChars());
        Scope* scx = sc.push();
        scx.depmsg = depmsg;
        StorageClassDeclaration.setScope(scx);
        scx.pop();
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class LinkDeclaration : AttribDeclaration
{
public:
    LINK linkage;

    extern (D) this(LINK p, Dsymbols* decl)
    {
        super(decl);
        //printf("LinkDeclaration(linkage = %d, decl = %p)\n", p, decl);
        linkage = p;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new LinkDeclaration(linkage, Dsymbol.arraySyntaxCopy(decl));
    }

    override Scope* newScope(Scope* sc)
    {
        return createNewScope(sc, sc.stc, this.linkage, sc.protection, sc.explicitProtection, sc.structalign, sc.inlining);
    }

    override char* toChars()
    {
        return cast(char*)"extern ()";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class ProtDeclaration : AttribDeclaration
{
public:
    Prot protection;
    Identifiers* pkg_identifiers;

    /**
     * Params:
     *  loc = source location of attribute token
     *  p = protection attribute data
     *  decl = declarations which are affected by this protection attribute
     */
    extern (D) this(Loc loc, Prot p, Dsymbols* decl)
    {
        super(decl);
        this.loc = loc;
        this.protection = p;
        //printf("decl = %p\n", decl);
    }

    /**
     * Params:
     *  loc = source location of attribute token
     *  pkg_identifiers = list of identifiers for a qualified package name
     *  decl = declarations which are affected by this protection attribute
     */
    extern (D) this(Loc loc, Identifiers* pkg_identifiers, Dsymbols* decl)
    {
        super(decl);
        this.loc = loc;
        this.protection.kind = PROTpackage;
        this.protection.pkg = null;
        this.pkg_identifiers = pkg_identifiers;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        if (protection.kind == PROTpackage)
            return new ProtDeclaration(this.loc, pkg_identifiers, Dsymbol.arraySyntaxCopy(decl));
        else
            return new ProtDeclaration(this.loc, protection, Dsymbol.arraySyntaxCopy(decl));
    }

    override Scope* newScope(Scope* sc)
    {
        if (pkg_identifiers)
            semantic(sc);
        return createNewScope(sc, sc.stc, sc.linkage, this.protection, 1, sc.structalign, sc.inlining);
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        if (pkg_identifiers)
        {
            Dsymbol tmp;
            Package.resolve(pkg_identifiers, &tmp, null);
            protection.pkg = tmp ? tmp.isPackage() : null;
            pkg_identifiers = null;
        }
        if (protection.kind == PROTpackage && protection.pkg && sc._module)
        {
            Module m = sc._module;
            Package pkg = m.parent ? m.parent.isPackage() : null;
            if (!pkg || !protection.pkg.isAncestorPackageOf(pkg))
                error("does not bind to one of ancestor packages of module '%s'", m.toPrettyChars(true));
        }
        return AttribDeclaration.addMember(sc, sds);
    }

    override const(char)* kind()
    {
        return "protection attribute";
    }

    override const(char)* toPrettyChars(bool)
    {
        assert(protection.kind > PROTundefined);
        OutBuffer buf;
        buf.writeByte('\'');
        protectionToBuffer(&buf, protection);
        buf.writeByte('\'');
        return buf.extractString();
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class AlignDeclaration : AttribDeclaration
{
public:
    uint salign;

    extern (D) this(uint sa, Dsymbols* decl)
    {
        super(decl);
        salign = sa;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new AlignDeclaration(salign, Dsymbol.arraySyntaxCopy(decl));
    }

    override Scope* newScope(Scope* sc)
    {
        return createNewScope(sc, sc.stc, sc.linkage, sc.protection, sc.explicitProtection, this.salign, sc.inlining);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class AnonDeclaration : AttribDeclaration
{
public:
    bool isunion;
    structalign_t alignment;
    int sem;        // 1 if successful semantic()

    extern (D) this(Loc loc, bool isunion, Dsymbols* decl)
    {
        super(decl);
        this.loc = loc;
        this.isunion = isunion;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new AnonDeclaration(loc, isunion, Dsymbol.arraySyntaxCopy(decl));
    }

    override void semantic(Scope* sc)
    {
        //printf("\tAnonDeclaration::semantic %s %p\n", isunion ? "union" : "struct", this);
        assert(sc.parent);
        Dsymbol p = sc.parent.pastMixin();
        AggregateDeclaration ad = p.isAggregateDeclaration();
        if (!ad)
        {
            .error(loc, "%s can only be a part of an aggregate, not %s %s", kind(), p.kind(), p.toChars());
            return;
        }
        alignment = sc.structalign;
        if (decl)
        {
            sc = sc.push();
            sc.stc &= ~(STCauto | STCscope | STCstatic | STCtls | STCgshared);
            sc.inunion = isunion;
            sc.flags = 0;
            for (size_t i = 0; i < decl.dim; i++)
            {
                Dsymbol s = (*decl)[i];
                s.semantic(sc);
            }
            sc = sc.pop();
        }
    }

    override void setFieldOffset(AggregateDeclaration ad, uint* poffset, bool isunion)
    {
        //printf("\tAnonDeclaration::setFieldOffset %s %p\n", isunion ? "union" : "struct", this);
        if (decl)
        {
            /* This works by treating an AnonDeclaration as an aggregate 'member',
             * so in order to place that member we need to compute the member's
             * size and alignment.
             */
            size_t fieldstart = ad.fields.dim;
            /* Hackishly hijack ad's structsize and alignsize fields
             * for use in our fake anon aggregate member.
             */
            uint savestructsize = ad.structsize;
            uint savealignsize = ad.alignsize;
            ad.structsize = 0;
            ad.alignsize = 0;
            uint offset = 0;
            for (size_t i = 0; i < decl.dim; i++)
            {
                Dsymbol s = (*decl)[i];
                s.setFieldOffset(ad, &offset, this.isunion);
                if (this.isunion)
                    offset = 0;
            }
            uint anonstructsize = ad.structsize;
            uint anonalignsize = ad.alignsize;
            ad.structsize = savestructsize;
            ad.alignsize = savealignsize;
            if (fieldstart == ad.fields.dim)
            {
                /* Bugzilla 13613: If the fields in this->members had been already
                 * added in ad->fields, just update *poffset for the subsequent
                 * field offset calculation.
                 */
                *poffset = ad.structsize;
                return;
            }
            // 0 sized structs are set to 1 byte
            // TODO: is this corect hebavior?
            if (anonstructsize == 0)
            {
                anonstructsize = 1;
                anonalignsize = 1;
            }
            /* Given the anon 'member's size and alignment,
             * go ahead and place it.
             */
            uint anonoffset = AggregateDeclaration.placeField(poffset, anonstructsize, anonalignsize, alignment, &ad.structsize, &ad.alignsize, isunion);
            // Add to the anon fields the base offset of this anonymous aggregate
            //printf("anon fields, anonoffset = %d\n", anonoffset);
            for (size_t i = fieldstart; i < ad.fields.dim; i++)
            {
                VarDeclaration v = ad.fields[i];
                //printf("\t[%d] %s %d\n", i, v->toChars(), v->offset);
                v.offset += anonoffset;
            }
        }
    }

    override const(char)* kind()
    {
        return (isunion ? "anonymous union" : "anonymous struct");
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class PragmaDeclaration : AttribDeclaration
{
public:
    Expressions* args;      // array of Expression's

    extern (D) this(Loc loc, Identifier ident, Expressions* args, Dsymbols* decl)
    {
        super(decl);
        this.loc = loc;
        this.ident = ident;
        this.args = args;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("PragmaDeclaration::syntaxCopy(%s)\n", toChars());
        assert(!s);
        return new PragmaDeclaration(loc, ident, Expression.arraySyntaxCopy(args), Dsymbol.arraySyntaxCopy(decl));
    }

    override void semantic(Scope* sc)
    {
        // Should be merged with PragmaStatement
        //printf("\tPragmaDeclaration::semantic '%s'\n",toChars());
        if (ident == Id.msg)
        {
            if (args)
            {
                for (size_t i = 0; i < args.dim; i++)
                {
                    Expression e = (*args)[i];
                    sc = sc.startCTFE();
                    e = e.semantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc.endCTFE();
                    // pragma(msg) is allowed to contain types as well as expressions
                    e = ctfeInterpretForPragmaMsg(e);
                    if (e.op == TOKerror)
                    {
                        errorSupplemental(loc, "while evaluating pragma(msg, %s)", (*args)[i].toChars());
                        return;
                    }
                    StringExp se = e.toStringExp();
                    if (se)
                    {
                        se = se.toUTF8(sc);
                        fprintf(stderr, "%.*s", cast(int)se.len, cast(char*)se.string);
                    }
                    else
                        fprintf(stderr, "%s", e.toChars());
                }
                fprintf(stderr, "\n");
            }
            goto Lnodecl;
        }
        else if (ident == Id.lib)
        {
            if (!args || args.dim != 1)
                error("string expected for library name");
            else
            {
                Expression e = (*args)[0];
                sc = sc.startCTFE();
                e = e.semantic(sc);
                e = resolveProperties(sc, e);
                sc = sc.endCTFE();
                e = e.ctfeInterpret();
                (*args)[0] = e;
                if (e.op == TOKerror)
                    goto Lnodecl;
                StringExp se = e.toStringExp();
                if (!se)
                    error("string expected for library name, not '%s'", e.toChars());
                else
                {
                    char* name = cast(char*)mem.xmalloc(se.len + 1);
                    memcpy(name, se.string, se.len);
                    name[se.len] = 0;
                    if (global.params.verbose)
                        fprintf(global.stdmsg, "library   %s\n", name);
                    if (global.params.moduleDeps && !global.params.moduleDepsFile)
                    {
                        OutBuffer* ob = global.params.moduleDeps;
                        Module imod = sc.instantiatingModule();
                        ob.writestring("depsLib ");
                        ob.writestring(imod.toPrettyChars());
                        ob.writestring(" (");
                        escapePath(ob, imod.srcfile.toChars());
                        ob.writestring(") : ");
                        ob.writestring(cast(char*)name);
                        ob.writenl();
                    }
                    mem.xfree(name);
                }
            }
            goto Lnodecl;
        }
        else if (ident == Id.startaddress)
        {
            if (!args || args.dim != 1)
                error("function name expected for start address");
            else
            {
                /* Bugzilla 11980:
                 * resolveProperties and ctfeInterpret call are not necessary.
                 */
                Expression e = (*args)[0];
                sc = sc.startCTFE();
                e = e.semantic(sc);
                sc = sc.endCTFE();
                (*args)[0] = e;
                Dsymbol sa = getDsymbol(e);
                if (!sa || !sa.isFuncDeclaration())
                    error("function name expected for start address, not '%s'", e.toChars());
            }
            goto Lnodecl;
        }
        else if (ident == Id.Pinline)
        {
            goto Ldecl;
        }
        else if (ident == Id.mangle)
        {
            if (!args)
                args = new Expressions();
            if (args.dim != 1)
            {
                error("string expected for mangled name");
                args.setDim(1);
                (*args)[0] = new ErrorExp(); // error recovery
                goto Ldecl;
            }
            Expression e = (*args)[0];
            e = e.semantic(sc);
            e = e.ctfeInterpret();
            (*args)[0] = e;
            if (e.op == TOKerror)
                goto Ldecl;
            StringExp se = e.toStringExp();
            if (!se)
            {
                error("string expected for mangled name, not '%s'", e.toChars());
                goto Ldecl;
            }
            if (!se.len)
            {
                error("zero-length string not allowed for mangled name");
                goto Ldecl;
            }
            if (se.sz != 1)
            {
                error("mangled name characters can only be of type char");
                goto Ldecl;
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
                    char* p = cast(char*)se.string;
                    dchar_t c = p[i];
                    if (c < 0x80)
                    {
                        if (c >= 'A' && c <= 'Z' || c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c != 0 && strchr("$%().:?@[]_", c))
                        {
                            ++i;
                            continue;
                        }
                        else
                        {
                            error("char 0x%02x not allowed in mangled name", c);
                            break;
                        }
                    }
                    if (const(char)* msg = utf_decodeChar(cast(char*)se.string, se.len, &i, &c))
                    {
                        error("%s", msg);
                        break;
                    }
                    if (!isUniAlpha(c))
                    {
                        error("char 0x%04x not allowed in mangled name", c);
                        break;
                    }
                }
            }
        }
        else if (global.params.ignoreUnsupportedPragmas)
        {
            if (global.params.verbose)
            {
                /* Print unrecognized pragmas
                 */
                fprintf(global.stdmsg, "pragma    %s", ident.toChars());
                if (args)
                {
                    for (size_t i = 0; i < args.dim; i++)
                    {
                        Expression e = (*args)[i];
                        sc = sc.startCTFE();
                        e = e.semantic(sc);
                        e = resolveProperties(sc, e);
                        sc = sc.endCTFE();
                        e = e.ctfeInterpret();
                        if (i == 0)
                            fprintf(global.stdmsg, " (");
                        else
                            fprintf(global.stdmsg, ",");
                        fprintf(global.stdmsg, "%s", e.toChars());
                    }
                    if (args.dim)
                        fprintf(global.stdmsg, ")");
                }
                fprintf(global.stdmsg, "\n");
            }
            goto Lnodecl;
        }
        else
            error("unrecognized pragma(%s)", ident.toChars());
    Ldecl:
        if (decl)
        {
            Scope* sc2 = newScope(sc);
            for (size_t i = 0; i < decl.dim; i++)
            {
                Dsymbol s = (*decl)[i];
                s.semantic(sc2);
                if (ident == Id.mangle)
                {
                    assert(args && args.dim == 1);
                    if (StringExp se = (*args)[0].toStringExp())
                    {
                        char* name = cast(char*)mem.xmalloc(se.len + 1);
                        memcpy(name, se.string, se.len);
                        name[se.len] = 0;
                        uint cnt = setMangleOverride(s, name);
                        if (cnt > 1)
                            error("can only apply to a single declaration");
                    }
                }
            }
            if (sc2 != sc)
                sc2.pop();
        }
        return;
    Lnodecl:
        if (decl)
        {
            error("pragma is missing closing ';'");
            goto Ldecl;
            // do them anyway, to avoid segfaults.
        }
    }

    override Scope* newScope(Scope* sc)
    {
        if (ident == Id.Pinline)
        {
            PINLINE inlining = PINLINEdefault;
            if (!args || args.dim == 0)
                inlining = PINLINEdefault;
            else if (args.dim != 1)
            {
                error("one boolean expression expected for pragma(inline), not %d", args.dim);
                args.setDim(1);
                (*args)[0] = new ErrorExp();
            }
            else
            {
                Expression e = (*args)[0];
                if (e.op != TOKint64 || !e.type.equals(Type.tbool))
                {
                    if (e.op != TOKerror)
                    {
                        error("pragma(inline, true or false) expected, not %s", e.toChars());
                        (*args)[0] = new ErrorExp();
                    }
                }
                else if (e.isBool(true))
                    inlining = PINLINEalways;
                else if (e.isBool(false))
                    inlining = PINLINEnever;
            }
            return createNewScope(sc, sc.stc, sc.linkage, sc.protection, sc.explicitProtection, sc.structalign, inlining);
        }
        return sc;
    }

    override const(char)* kind()
    {
        return "pragma";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) class ConditionalDeclaration : AttribDeclaration
{
public:
    Condition condition;
    Dsymbols* elsedecl;     // array of Dsymbol's for else block

    final extern (D) this(Condition condition, Dsymbols* decl, Dsymbols* elsedecl)
    {
        super(decl);
        //printf("ConditionalDeclaration::ConditionalDeclaration()\n");
        this.condition = condition;
        this.elsedecl = elsedecl;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new ConditionalDeclaration(condition.syntaxCopy(), Dsymbol.arraySyntaxCopy(decl), Dsymbol.arraySyntaxCopy(elsedecl));
    }

    override final bool oneMember(Dsymbol* ps, Identifier ident)
    {
        //printf("ConditionalDeclaration::oneMember(), inc = %d\n", condition->inc);
        if (condition.inc)
        {
            Dsymbols* d = condition.include(null, null) ? decl : elsedecl;
            return Dsymbol.oneMembers(d, ps, ident);
        }
        else
        {
            bool res = (Dsymbol.oneMembers(decl, ps, ident) && *ps is null && Dsymbol.oneMembers(elsedecl, ps, ident) && *ps is null);
            *ps = null;
            return res;
        }
    }

    // Decide if 'then' or 'else' code should be included
    override Dsymbols* include(Scope* sc, ScopeDsymbol sds)
    {
        //printf("ConditionalDeclaration::include(sc = %p) scope = %p\n", sc, scope);
        assert(condition);
        return condition.include(_scope ? _scope : sc, sds) ? decl : elsedecl;
    }

    override final void addComment(const(char)* comment)
    {
        /* Because addComment is called by the parser, if we called
         * include() it would define a version before it was used.
         * But it's no problem to drill down to both decl and elsedecl,
         * so that's the workaround.
         */
        if (comment)
        {
            Dsymbols* d = decl;
            for (int j = 0; j < 2; j++)
            {
                if (d)
                {
                    for (size_t i = 0; i < d.dim; i++)
                    {
                        Dsymbol s = (*d)[i];
                        //printf("ConditionalDeclaration::addComment %s\n", s->toChars());
                        s.addComment(comment);
                    }
                }
                d = elsedecl;
            }
        }
    }

    override void setScope(Scope* sc)
    {
        Dsymbols* d = include(sc, null);
        //printf("\tConditionalDeclaration::setScope '%s', d = %p\n",toChars(), d);
        if (d)
        {
            for (size_t i = 0; i < d.dim; i++)
            {
                Dsymbol s = (*d)[i];
                s.setScope(sc);
            }
        }
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class StaticIfDeclaration : ConditionalDeclaration
{
public:
    ScopeDsymbol scopesym;
    int addisdone;

    extern (D) this(Condition condition, Dsymbols* decl, Dsymbols* elsedecl)
    {
        super(condition, decl, elsedecl);
        //printf("StaticIfDeclaration::StaticIfDeclaration()\n");
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(!s);
        return new StaticIfDeclaration(condition.syntaxCopy(), Dsymbol.arraySyntaxCopy(decl), Dsymbol.arraySyntaxCopy(elsedecl));
    }

    /****************************************
     * Different from other AttribDeclaration subclasses, include() call requires
     * the completion of addMember and setScope phases.
     */
    override Dsymbols* include(Scope* sc, ScopeDsymbol sds)
    {
        //printf("StaticIfDeclaration::include(sc = %p) scope = %p\n", sc, scope);
        if (condition.inc == 0)
        {
            assert(scopesym); // addMember is already done
            assert(_scope); // setScope is already done
            Dsymbols* d = ConditionalDeclaration.include(_scope, scopesym);
            if (d && !addisdone)
            {
                // Add members lazily.
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    s.addMember(_scope, scopesym);
                }
                // Set the member scopes lazily.
                for (size_t i = 0; i < d.dim; i++)
                {
                    Dsymbol s = (*d)[i];
                    s.setScope(_scope);
                }
                addisdone = 1;
            }
            return d;
        }
        else
        {
            return ConditionalDeclaration.include(sc, scopesym);
        }
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        //printf("StaticIfDeclaration::addMember() '%s'\n", toChars());
        /* This is deferred until the condition evaluated later (by the include() call),
         * so that expressions in the condition can refer to declarations
         * in the same scope, such as:
         *
         * template Foo(int i)
         * {
         *     const int j = i + 1;
         *     static if (j == 3)
         *         const int k;
         * }
         */
        this.scopesym = sds;
    }

    override void semantic(Scope* sc)
    {
        AttribDeclaration.semantic(sc);
    }

    override void importAll(Scope* sc)
    {
        // do not evaluate condition before semantic pass
    }

    override void setScope(Scope* sc)
    {
        // do not evaluate condition before semantic pass
        // But do set the scope, in case we need it for forward referencing
        Dsymbol.setScope(sc);
    }

    override const(char)* kind()
    {
        return "static if";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * Mixin declarations, like:
 *      mixin("int x");
 */
extern (C++) final class CompileDeclaration : AttribDeclaration
{
public:
    Expression exp;
    ScopeDsymbol scopesym;
    int compiled;

    extern (D) this(Loc loc, Expression exp)
    {
        super(null);
        //printf("CompileDeclaration(loc = %d)\n", loc.linnum);
        this.loc = loc;
        this.exp = exp;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("CompileDeclaration::syntaxCopy('%s')\n", toChars());
        return new CompileDeclaration(loc, exp.syntaxCopy());
    }

    override void addMember(Scope* sc, ScopeDsymbol sds)
    {
        //printf("CompileDeclaration::addMember(sc = %p, sds = %p, memnum = %d)\n", sc, sds, memnum);
        this.scopesym = sds;
    }

    override void setScope(Scope* sc)
    {
        Dsymbol.setScope(sc);
    }

    void compileIt(Scope* sc)
    {
        //printf("CompileDeclaration::compileIt(loc = %d) %s\n", loc.linnum, exp->toChars());
        sc = sc.startCTFE();
        exp = exp.semantic(sc);
        exp = resolveProperties(sc, exp);
        sc = sc.endCTFE();
        if (exp.op != TOKerror)
        {
            Expression e = exp.ctfeInterpret();
            StringExp se = e.toStringExp();
            if (!se)
                exp.error("argument to mixin must be a string, not (%s) of type %s", exp.toChars(), exp.type.toChars());
            else
            {
                se = se.toUTF8(sc);
                uint errors = global.errors;
                scope Parser p = new Parser(loc, sc._module, cast(char*)se.string, se.len, 0);
                p.nextToken();
                decl = p.parseDeclDefs(0);
                if (p.token.value != TOKeof)
                    exp.error("incomplete mixin declaration (%s)", se.toChars());
                if (p.errors)
                {
                    assert(global.errors != errors);
                    decl = null;
                }
            }
        }
    }

    override void semantic(Scope* sc)
    {
        //printf("CompileDeclaration::semantic()\n");
        if (!compiled)
        {
            compileIt(sc);
            AttribDeclaration.addMember(sc, scopesym);
            compiled = 1;
            if (_scope && decl)
            {
                for (size_t i = 0; i < decl.dim; i++)
                {
                    Dsymbol s = (*decl)[i];
                    s.setScope(_scope);
                }
            }
        }
        AttribDeclaration.semantic(sc);
    }

    override const(char)* kind()
    {
        return "mixin";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * User defined attributes look like:
 *      @(args, ...)
 */
extern (C++) final class UserAttributeDeclaration : AttribDeclaration
{
public:
    Expressions* atts;

    extern (D) this(Expressions* atts, Dsymbols* decl)
    {
        super(decl);
        //printf("UserAttributeDeclaration()\n");
        this.atts = atts;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("UserAttributeDeclaration::syntaxCopy('%s')\n", toChars());
        assert(!s);
        return new UserAttributeDeclaration(Expression.arraySyntaxCopy(this.atts), Dsymbol.arraySyntaxCopy(decl));
    }

    override Scope* newScope(Scope* sc)
    {
        Scope* sc2 = sc;
        if (atts && atts.dim)
        {
            // create new one for changes
            sc2 = sc.copy();
            sc2.userAttribDecl = this;
        }
        return sc2;
    }

    override void semantic(Scope* sc)
    {
        //printf("UserAttributeDeclaration::semantic() %p\n", this);
        if (decl && !_scope)
            Dsymbol.setScope(sc); // for function local symbols
        return AttribDeclaration.semantic(sc);
    }

    override void semantic2(Scope* sc)
    {
        if (decl && atts && atts.dim)
        {
            if (atts && atts.dim && _scope)
            {
                _scope = null;
                arrayExpressionSemantic(atts, sc, true); // run semantic
            }
        }
        AttribDeclaration.semantic2(sc);
    }

    override void setScope(Scope* sc)
    {
        //printf("UserAttributeDeclaration::setScope() %p\n", this);
        if (decl)
            Dsymbol.setScope(sc); // for forward reference of UDAs
        return AttribDeclaration.setScope(sc);
    }

    static Expressions* concat(Expressions* udas1, Expressions* udas2)
    {
        Expressions* udas;
        if (!udas1 || udas1.dim == 0)
            udas = udas2;
        else if (!udas2 || udas2.dim == 0)
            udas = udas1;
        else
        {
            /* Create a new tuple that combines them
             * (do not append to left operand, as this is a copy-on-write operation)
             */
            udas = new Expressions();
            udas.push(new TupleExp(Loc(), udas1));
            udas.push(new TupleExp(Loc(), udas2));
        }
        return udas;
    }

    Expressions* getAttributes()
    {
        if (_scope)
        {
            Scope* sc = _scope;
            _scope = null;
            arrayExpressionSemantic(atts, sc);
        }
        auto exps = new Expressions();
        if (userAttribDecl)
            exps.push(new TupleExp(Loc(), userAttribDecl.getAttributes()));
        if (atts && atts.dim)
            exps.push(new TupleExp(Loc(), atts));
        return exps;
    }

    override const(char)* kind()
    {
        return "UserAttribute";
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) static uint setMangleOverride(Dsymbol s, char* sym)
{
    AttribDeclaration ad = s.isAttribDeclaration();
    if (ad)
    {
        Dsymbols* decls = ad.include(null, null);
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
