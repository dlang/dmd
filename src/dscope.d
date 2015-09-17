// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.dscope;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.attrib;
import ddmd.dclass;
import ddmd.declaration;
import ddmd.dmodule;
import ddmd.doc;
import ddmd.dsymbol;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.func;
import ddmd.globals;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.mtype;
import ddmd.root.aav;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.root.speller;
import ddmd.root.stringtable;
import ddmd.statement;

extern (C++) bool mergeFieldInit(Loc loc, ref uint fieldInit, uint fi, bool mustInit)
{
    if (fi != fieldInit)
    {
        // Have any branches returned?
        bool aRet = (fi & CSXreturn) != 0;
        bool bRet = (fieldInit & CSXreturn) != 0;
        // Have any branches halted?
        bool aHalt = (fi & CSXhalt) != 0;
        bool bHalt = (fieldInit & CSXhalt) != 0;
        bool ok;
        if (aHalt && bHalt)
        {
            ok = true;
            fieldInit = CSXhalt;
        }
        else if (!aHalt && aRet)
        {
            ok = !mustInit || (fi & CSXthis_ctor);
            fieldInit = fieldInit;
        }
        else if (!bHalt && bRet)
        {
            ok = !mustInit || (fieldInit & CSXthis_ctor);
            fieldInit = fi;
        }
        else if (aHalt)
        {
            ok = !mustInit || (fieldInit & CSXthis_ctor);
            fieldInit = fieldInit;
        }
        else if (bHalt)
        {
            ok = !mustInit || (fi & CSXthis_ctor);
            fieldInit = fi;
        }
        else
        {
            ok = !mustInit || !((fieldInit ^ fi) & CSXthis_ctor);
            fieldInit |= fi;
        }
        return ok;
    }
    return true;
}

/************************************************
 * Given the failed search attempt, try to find
 * one with a close spelling.
 */
extern (C++) void* scope_search_fp(void* arg, const(char)* seed, int* cost)
{
    //printf("scope_search_fp('%s')\n", seed);
    /* If not in the lexer's string table, it certainly isn't in the symbol table.
     * Doing this first is a lot faster.
     */
    size_t len = strlen(seed);
    if (!len)
        return null;
    Identifier id = Identifier.lookup(seed, len);
    if (!id)
        return null;
    Scope* sc = cast(Scope*)arg;
    Module.clearCache();
    Dsymbol scopesym = null;
    Dsymbol s = sc.search(Loc(), id, &scopesym, IgnoreErrors);
    if (s)
    {
        for (*cost = 0; sc; sc = sc.enclosing, (*cost)++)
            if (sc.scopesym == scopesym)
                break;
        if (scopesym != s.parent)
        {
            (*cost)++; // got to the symbol through an import
            if (s.prot().kind == PROTprivate)
                return null;
        }
    }
    return cast(void*)s;
}

enum CSXthis_ctor = 1;
// called this()
enum CSXsuper_ctor = 2;
// called super()
enum CSXthis = 4;
// referenced this
enum CSXsuper = 8;
// referenced super
enum CSXlabel = 0x10;
// seen a label
enum CSXreturn = 0x20;
// seen a return statement
enum CSXany_ctor = 0x40;
// either this() or super() was called
enum CSXhalt = 0x80;
// assert(0)
// Flags that would not be inherited beyond scope nesting
enum SCOPEctor = 0x0001;
// constructor type
enum SCOPEnoaccesscheck = 0x0002;
// don't do access checks
enum SCOPEcondition = 0x0004;
// inside static if/assert condition
enum SCOPEdebug = 0x0008;
// inside debug conditional
// Flags that would be inherited beyond scope nesting
enum SCOPEconstraint = 0x0010;
// inside template constraint
enum SCOPEinvariant = 0x0020;
// inside invariant code
enum SCOPErequire = 0x0040;
// inside in contract code
enum SCOPEensure = 0x0060;
// inside out contract code
enum SCOPEcontract = 0x0060;
// [mask] we're inside contract code
enum SCOPEctfe = 0x0080;
// inside a ctfe-only expression
enum SCOPEcompile = 0x0100;
// inside __traits(compile)
enum SCOPEfree = 0x8000;

// is on free list
struct Scope
{
    Scope* enclosing = null; // enclosing Scope
    Module _module = null; // Root module
    ScopeDsymbol scopesym = null; // current symbol
    ScopeDsymbol sds = null; // if in static if, and declaring new symbols,
    // sds gets the addMember()
    FuncDeclaration func = null; // function we are in
    Dsymbol parent = null; // parent to use
    LabelStatement slabel = null; // enclosing labelled statement
    SwitchStatement sw = null; // enclosing switch statement
    TryFinallyStatement tf = null; // enclosing try finally statement
    OnScopeStatement os = null; // enclosing scope(xxx) statement
    Statement sbreak = null; // enclosing statement that supports "break"
    Statement scontinue = null; // enclosing statement that supports "continue"
    ForeachStatement fes = null; // if nested function for ForeachStatement, this is it
    Scope* callsc = null; // used for __FUNCTION__, __PRETTY_FUNCTION__ and __MODULE__
    int inunion = 0; // we're processing members of a union
    int nofree = 0; // set if shouldn't free it
    int noctor = 0; // set if constructor calls aren't allowed
    int intypeof = 0; // in typeof(exp)
    VarDeclaration lastVar = null; // Previous symbol used to prevent goto-skips-init
    /* If  minst && !tinst, it's in definitely non-speculative scope (eg. module member scope).
     * If !minst && !tinst, it's in definitely speculative scope (eg. template constraint).
     * If  minst &&  tinst, it's in instantiated code scope without speculation.
     * If !minst &&  tinst, it's in instantiated code scope with speculation.
     */
    Module minst = null; // root module where the instantiated templates should belong to
    TemplateInstance tinst = null; // enclosing template instance
    uint callSuper = 0; // primitive flow analysis for constructors
    uint* fieldinit = null;
    size_t fieldinit_dim = 0;
    structalign_t structalign = STRUCTALIGN_DEFAULT; // alignment for struct members
    LINK linkage = LINKd; // linkage for external functions
    PINLINE inlining = PINLINEdefault; // inlining strategy for functions
    Prot protection = Prot(PROTpublic); // protection for class members
    int explicitProtection = 0; // set if in an explicit protection attribute
    StorageClass stc = 0; // storage class
    char* depmsg = null; // customized deprecation message
    uint flags = 0;
    UserAttributeDeclaration userAttribDecl = null; // user defined attributes
    DocComment* lastdc = null; // documentation comment for last symbol at this scope
    AA* anchorCounts = null; // lookup duplicate anchor name count
    Identifier prevAnchor = null; // qualified symbol name of last doc anchor
    extern (C++) static __gshared Scope* freelist = null;

    extern (C++) static Scope* alloc()
    {
        if (freelist)
        {
            Scope* s = freelist;
            freelist = s.enclosing;
            //printf("freelist %p\n", s);
            assert(s.flags & SCOPEfree);
            s.flags &= ~SCOPEfree;
            return s;
        }
        return new Scope();
    }

    extern (C++) static Scope* createGlobal(Module _module)
    {
        Scope* sc = Scope.alloc();
        memset(sc, 0, Scope.sizeof);
        sc.structalign = STRUCTALIGN_DEFAULT;
        sc.linkage = LINKd;
        sc.inlining = PINLINEdefault;
        sc.protection = Prot(PROTpublic);
        sc._module = _module;
        sc.tinst = null;
        sc.minst = _module;
        sc.scopesym = new ScopeDsymbol();
        sc.scopesym.symtab = new DsymbolTable();
        // Add top level package as member of this global scope
        Dsymbol m = _module;
        while (m.parent)
            m = m.parent;
        m.addMember(null, sc.scopesym);
        m.parent = null; // got changed by addMember()
        // Create the module scope underneath the global scope
        sc = sc.push(_module);
        sc.parent = _module;
        return sc;
    }

    extern (C++) Scope* copy()
    {
        Scope* sc = Scope.alloc();
        memcpy(sc, &this, Scope.sizeof);
        /* Bugzilla 11777: The copied scope should not inherit fieldinit.
         */
        sc.fieldinit = null;
        return sc;
    }

    extern (C++) Scope* push()
    {
        Scope* s = copy();
        //printf("Scope::push(this = %p) new = %p\n", this, s);
        assert(!(flags & SCOPEfree));
        s.scopesym = null;
        s.sds = null;
        s.enclosing = &this;
        debug
        {
            if (enclosing)
                assert(!(enclosing.flags & SCOPEfree));
            if (s == enclosing)
            {
                printf("this = %p, enclosing = %p, enclosing->enclosing = %p\n", s, &this, enclosing);
            }
            assert(s != enclosing);
        }
        s.slabel = null;
        s.nofree = 0;
        s.fieldinit = saveFieldInit();
        s.flags = (flags & (SCOPEcontract | SCOPEdebug | SCOPEctfe | SCOPEcompile | SCOPEconstraint));
        s.lastdc = null;
        assert(&this != s);
        return s;
    }

    extern (C++) Scope* push(ScopeDsymbol ss)
    {
        //printf("Scope::push(%s)\n", ss->toChars());
        Scope* s = push();
        s.scopesym = ss;
        return s;
    }

    extern (C++) Scope* pop()
    {
        //printf("Scope::pop() %p nofree = %d\n", this, nofree);
        Scope* enc = enclosing;
        if (enclosing)
        {
            enclosing.callSuper |= callSuper;
            if (enclosing.fieldinit && fieldinit)
            {
                assert(fieldinit != enclosing.fieldinit);
                size_t dim = fieldinit_dim;
                for (size_t i = 0; i < dim; i++)
                    enclosing.fieldinit[i] |= fieldinit[i];
                mem.xfree(fieldinit);
                fieldinit = null;
            }
        }
        if (!nofree)
        {
            enclosing = freelist;
            freelist = &this;
            flags |= SCOPEfree;
        }
        return enc;
    }

    extern (C++) Scope* startCTFE()
    {
        Scope* sc = this.push();
        sc.flags = this.flags | SCOPEctfe;
        version (none)
        {
            /* TODO: Currently this is not possible, because we need to
             * unspeculative some types and symbols if they are necessary for the
             * final executable. Consider:
             *
             * struct S(T) {
             *   string toString() const { return "instantiated"; }
             * }
             * enum x = S!int();
             * void main() {
             *   // To call x.toString in runtime, compiler should unspeculative S!int.
             *   assert(x.toString() == "instantiated");
             * }
             */
            // If a template is instantiated from CT evaluated expression,
            // compiler can elide its code generation.
            sc.tinst = null;
            sc.minst = null;
        }
        return sc;
    }

    extern (C++) Scope* endCTFE()
    {
        assert(flags & SCOPEctfe);
        return pop();
    }

    extern (C++) void mergeCallSuper(Loc loc, uint cs)
    {
        // This does a primitive flow analysis to support the restrictions
        // regarding when and how constructors can appear.
        // It merges the results of two paths.
        // The two paths are callSuper and cs; the result is merged into callSuper.
        if (cs != callSuper)
        {
            // Have ALL branches called a constructor?
            int aAll = (cs & (CSXthis_ctor | CSXsuper_ctor)) != 0;
            int bAll = (callSuper & (CSXthis_ctor | CSXsuper_ctor)) != 0;
            // Have ANY branches called a constructor?
            bool aAny = (cs & CSXany_ctor) != 0;
            bool bAny = (callSuper & CSXany_ctor) != 0;
            // Have any branches returned?
            bool aRet = (cs & CSXreturn) != 0;
            bool bRet = (callSuper & CSXreturn) != 0;
            // Have any branches halted?
            bool aHalt = (cs & CSXhalt) != 0;
            bool bHalt = (callSuper & CSXhalt) != 0;
            bool ok = true;
            if (aHalt && bHalt)
            {
                callSuper = CSXhalt;
            }
            else if ((!aHalt && aRet && !aAny && bAny) || (!bHalt && bRet && !bAny && aAny))
            {
                // If one has returned without a constructor call, there must be never
                // have been ctor calls in the other.
                ok = false;
            }
            else if (aHalt || aRet && aAll)
            {
                // If one branch has called a ctor and then exited, anything the
                // other branch has done is OK (except returning without a
                // ctor call, but we already checked that).
                callSuper |= cs & (CSXany_ctor | CSXlabel);
            }
            else if (bHalt || bRet && bAll)
            {
                callSuper = cs | (callSuper & (CSXany_ctor | CSXlabel));
            }
            else
            {
                // Both branches must have called ctors, or both not.
                ok = (aAll == bAll);
                // If one returned without a ctor, we must remember that
                // (Don't bother if we've already found an error)
                if (ok && aRet && !aAny)
                    callSuper |= CSXreturn;
                callSuper |= cs & (CSXany_ctor | CSXlabel);
            }
            if (!ok)
                error(loc, "one path skips constructor");
        }
    }

    extern (C++) uint* saveFieldInit()
    {
        uint* fi = null;
        if (fieldinit) // copy
        {
            size_t dim = fieldinit_dim;
            fi = cast(uint*)mem.xmalloc(uint.sizeof * dim);
            for (size_t i = 0; i < dim; i++)
                fi[i] = fieldinit[i];
        }
        return fi;
    }

    extern (C++) void mergeFieldInit(Loc loc, uint* fies)
    {
        if (fieldinit && fies)
        {
            FuncDeclaration f = func;
            if (fes)
                f = fes.func;
            AggregateDeclaration ad = f.isAggregateMember2();
            assert(ad);
            for (size_t i = 0; i < ad.fields.dim; i++)
            {
                VarDeclaration v = ad.fields[i];
                bool mustInit = (v.storage_class & STCnodefaultctor || v.type.needsNested());
                if (!.mergeFieldInit(loc, fieldinit[i], fies[i], mustInit))
                {
                    .error(loc, "one path skips field %s", ad.fields[i].toChars());
                }
            }
        }
    }

    extern (C++) Module instantiatingModule()
    {
        // TODO: in speculative context, returning 'module' is correct?
        return minst ? minst : _module;
    }

    extern (C++) Dsymbol search(Loc loc, Identifier ident, Dsymbol* pscopesym, int flags = IgnoreNone)
    {
        //printf("Scope::search(%p, '%s')\n", this, ident->toChars());
        if (ident == Id.empty)
        {
            // Look for module scope
            for (Scope* sc = &this; sc; sc = sc.enclosing)
            {
                assert(sc != sc.enclosing);
                if (!sc.scopesym)
                    continue;
                if (Dsymbol s = sc.scopesym.isModule())
                {
                    //printf("\tfound %s.%s\n", s->parent ? s->parent->toChars() : "", s->toChars());
                    if (pscopesym)
                        *pscopesym = sc.scopesym;
                    return s;
                }
            }
            return null;
        }
        for (Scope* sc = &this; sc; sc = sc.enclosing)
        {
            assert(sc != sc.enclosing);
            if (!sc.scopesym)
                continue;
            //printf("\tlooking in scopesym '%s', kind = '%s'\n", sc->scopesym->toChars(), sc->scopesym->kind());
            if (Dsymbol s = sc.scopesym.search(loc, ident, flags))
            {
                if (ident == Id.length && sc.scopesym.isArrayScopeSymbol() && sc.enclosing && sc.enclosing.search(loc, ident, null, flags))
                {
                    warning(s.loc, "array 'length' hides other 'length' name in outer scope");
                }
                //printf("\tfound %s.%s, kind = '%s'\n", s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
                if (pscopesym)
                    *pscopesym = sc.scopesym;
                return s;
            }
        }
        return null;
    }

    extern (C++) Dsymbol search_correct(Identifier ident)
    {
        if (global.gag)
            return null; // don't do it for speculative compiles; too time consuming
        return cast(Dsymbol)speller(ident.toChars(), &scope_search_fp, &this, idchars);
    }

    extern (C++) Dsymbol insert(Dsymbol s)
    {
        if (VarDeclaration vd = s.isVarDeclaration())
        {
            if (lastVar)
                vd.lastVar = lastVar;
            lastVar = vd;
        }
        else if (WithScopeSymbol ss = s.isWithScopeSymbol())
        {
            if (VarDeclaration vd = ss.withstate.wthis)
            {
                if (lastVar)
                    vd.lastVar = lastVar;
                lastVar = vd;
            }
            return null;
        }
        for (Scope* sc = &this; sc; sc = sc.enclosing)
        {
            //printf("\tsc = %p\n", sc);
            if (sc.scopesym)
            {
                //printf("\t\tsc->scopesym = %p\n", sc->scopesym);
                if (!sc.scopesym.symtab)
                    sc.scopesym.symtab = new DsymbolTable();
                return sc.scopesym.symtabInsert(s);
            }
        }
        assert(0);
    }

    /********************************************
     * Search enclosing scopes for ClassDeclaration.
     */
    extern (C++) ClassDeclaration getClassScope()
    {
        for (Scope* sc = &this; sc; sc = sc.enclosing)
        {
            if (!sc.scopesym)
                continue;
            ClassDeclaration cd = sc.scopesym.isClassDeclaration();
            if (cd)
                return cd;
        }
        return null;
    }

    /********************************************
     * Search enclosing scopes for ClassDeclaration.
     */
    extern (C++) AggregateDeclaration getStructClassScope()
    {
        for (Scope* sc = &this; sc; sc = sc.enclosing)
        {
            if (!sc.scopesym)
                continue;
            AggregateDeclaration ad = sc.scopesym.isClassDeclaration();
            if (ad)
                return ad;
            ad = sc.scopesym.isStructDeclaration();
            if (ad)
                return ad;
        }
        return null;
    }

    /*******************************************
     * For TemplateDeclarations, we need to remember the Scope
     * where it was declared. So mark the Scope as not
     * to be free'd.
     */
    extern (C++) void setNoFree()
    {
        //int i = 0;
        //printf("Scope::setNoFree(this = %p)\n", this);
        for (Scope* sc = &this; sc; sc = sc.enclosing)
        {
            //printf("\tsc = %p\n", sc);
            sc.nofree = 1;
            assert(!(flags & SCOPEfree));
            //assert(sc != sc->enclosing);
            //assert(!sc->enclosing || sc != sc->enclosing->enclosing);
            //if (++i == 10)
            //assert(0);
        }
    }

    extern (D) this(ref Scope sc)
    {
        this._module = sc._module;
        this.scopesym = sc.scopesym;
        this.sds = sc.sds;
        this.enclosing = sc.enclosing;
        this.parent = sc.parent;
        this.sw = sc.sw;
        this.tf = sc.tf;
        this.os = sc.os;
        this.tinst = sc.tinst;
        this.minst = sc.minst;
        this.sbreak = sc.sbreak;
        this.scontinue = sc.scontinue;
        this.fes = sc.fes;
        this.callsc = sc.callsc;
        this.structalign = sc.structalign;
        this.func = sc.func;
        this.slabel = sc.slabel;
        this.linkage = sc.linkage;
        this.inlining = sc.inlining;
        this.protection = sc.protection;
        this.explicitProtection = sc.explicitProtection;
        this.stc = sc.stc;
        this.depmsg = sc.depmsg;
        this.inunion = sc.inunion;
        this.nofree = sc.nofree;
        this.noctor = sc.noctor;
        this.intypeof = sc.intypeof;
        this.lastVar = sc.lastVar;
        this.callSuper = sc.callSuper;
        this.fieldinit = sc.fieldinit;
        this.fieldinit_dim = sc.fieldinit_dim;
        this.flags = sc.flags;
        this.lastdc = sc.lastdc;
        this.anchorCounts = sc.anchorCounts;
        this.prevAnchor = sc.prevAnchor;
        this.userAttribDecl = sc.userAttribDecl;
    }
}
