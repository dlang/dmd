/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _dscope.d)
 */

module ddmd.dscope;

import core.stdc.stdio;
import core.stdc.string;
import ddmd.aggregate;
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
import ddmd.id;
import ddmd.identifier;
import ddmd.root.outbuffer;
import ddmd.root.rmem;
import ddmd.root.speller;
import ddmd.statement;

//version=LOGSEARCH;

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

enum CSXthis_ctor       = 0x01;     /// called this()
enum CSXsuper_ctor      = 0x02;     /// called super()
enum CSXthis            = 0x04;     /// referenced this
enum CSXsuper           = 0x08;     /// referenced super
enum CSXlabel           = 0x10;     /// seen a label
enum CSXreturn          = 0x20;     /// seen a return statement
enum CSXany_ctor        = 0x40;     /// either this() or super() was called
enum CSXhalt            = 0x80;     /// assert(0)

// Flags that would not be inherited beyond scope nesting
enum SCOPEctor          = 0x0001;   /// constructor type
enum SCOPEcondition     = 0x0004;   /// inside static if/assert condition
enum SCOPEdebug         = 0x0008;   /// inside debug conditional

// Flags that would be inherited beyond scope nesting
enum SCOPEnoaccesscheck = 0x0002;   /// don't do access checks
enum SCOPEconstraint    = 0x0010;   /// inside template constraint
enum SCOPEinvariant     = 0x0020;   /// inside invariant code
enum SCOPErequire       = 0x0040;   /// inside in contract code
enum SCOPEensure        = 0x0060;   /// inside out contract code
enum SCOPEcontract      = 0x0060;   /// [mask] we're inside contract code
enum SCOPEctfe          = 0x0080;   /// inside a ctfe-only expression
enum SCOPEcompile       = 0x0100;   /// inside __traits(compile)
enum SCOPEignoresymbolvisibility    = 0x0200;   /// ignore symbol visibility (Bugzilla 15907)
enum SCOPEfree          = 0x8000;   /// is on free list

enum SCOPEfullinst      = 0x10000;  /// fully instantiate templates

struct Scope
{
    Scope* enclosing;               /// enclosing Scope

    Module _module;                 /// Root module
    ScopeDsymbol scopesym;          /// current symbol
    ScopeDsymbol sds;               /// if in static if, and declaring new symbols, sds gets the addMember()
    FuncDeclaration func;           /// function we are in
    Dsymbol parent;                 /// parent to use
    LabelStatement slabel;          /// enclosing labelled statement
    SwitchStatement sw;             /// enclosing switch statement
    TryFinallyStatement tf;         /// enclosing try finally statement
    OnScopeStatement os;            /// enclosing scope(xxx) statement
    Statement sbreak;               /// enclosing statement that supports "break"
    Statement scontinue;            /// enclosing statement that supports "continue"
    ForeachStatement fes;           /// if nested function for ForeachStatement, this is it
    Scope* callsc;                  /// used for __FUNCTION__, __PRETTY_FUNCTION__ and __MODULE__
    int inunion;                    /// we're processing members of a union
    int nofree;                     /// set if shouldn't free it
    int noctor;                     /// set if constructor calls aren't allowed
    int intypeof;                   /// in typeof(exp)
    VarDeclaration lastVar;         /// Previous symbol used to prevent goto-skips-init

    /* If  minst && !tinst, it's in definitely non-speculative scope (eg. module member scope).
     * If !minst && !tinst, it's in definitely speculative scope (eg. template constraint).
     * If  minst &&  tinst, it's in instantiated code scope without speculation.
     * If !minst &&  tinst, it's in instantiated code scope with speculation.
     */
    Module minst;                   /// root module where the instantiated templates should belong to
    TemplateInstance tinst;         /// enclosing template instance

    // primitive flow analysis for constructors
    uint callSuper;

    // primitive flow analysis for field initializations
    uint* fieldinit;
    size_t fieldinit_dim;

    /// alignment for struct members
    AlignDeclaration aligndecl;

    /// linkage for external functions
    LINK linkage = LINKd;

    /// mangle type
    CPPMANGLE cppmangle = CPPMANGLE.def;

    /// inlining strategy for functions
    PINLINE inlining = PINLINEdefault;

    /// protection for class members
    Prot protection = Prot(PROTpublic);
    int explicitProtection;         /// set if in an explicit protection attribute

    StorageClass stc;               /// storage class

    DeprecatedDeclaration depdecl;  /// customized deprecation message

    uint flags;

    // user defined attributes
    UserAttributeDeclaration userAttribDecl;

    DocComment* lastdc;        /// documentation comment for last symbol at this scope
    uint[void*] anchorCounts;  /// lookup duplicate anchor name count
    Identifier prevAnchor;     /// qualified symbol name of last doc anchor

    extern (C++) static __gshared Scope* freelist;

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
        *sc = Scope.init;
        sc._module = _module;
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
        *sc = this;
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
        s.flags = (flags & (SCOPEcontract | SCOPEdebug | SCOPEctfe | SCOPEcompile | SCOPEconstraint |
                            SCOPEnoaccesscheck | SCOPEignoresymbolvisibility));
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
            if (fieldinit)
            {
                if (enclosing.fieldinit)
                {
                    assert(fieldinit != enclosing.fieldinit);
                    foreach (i; 0 .. fieldinit_dim)
                        enclosing.fieldinit[i] |= fieldinit[i];
                }
                freeFieldinit();
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

    void allocFieldinit(size_t dim)
    {
        fieldinit = cast(typeof(fieldinit))mem.xcalloc(typeof(*fieldinit).sizeof, dim);
        fieldinit_dim = dim;
    }

    void freeFieldinit()
    {
        if (fieldinit)
            mem.xfree(fieldinit);
        fieldinit = null;
        fieldinit_dim = 0;
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
            auto ad = f.isMember2();
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

    /************************************
     * Perform unqualified name lookup by following the chain of scopes up
     * until found.
     *
     * Params:
     *  loc = location to use for error messages
     *  ident = name to look up
     *  pscopesym = if supplied and name is found, set to scope that ident was found in
     *  flags = modify search based on flags
     *
     * Returns:
     *  symbol if found, null if not
     */
    extern (C++) Dsymbol search(Loc loc, Identifier ident, Dsymbol* pscopesym, int flags = IgnoreNone)
    {
        version (LOGSEARCH)
        {
            printf("Scope.search(%p, '%s' flags=x%x)\n", &this, ident.toChars(), flags);
            // Print scope chain
            for (Scope* sc = &this; sc; sc = sc.enclosing)
            {
                if (!sc.scopesym)
                    continue;
                printf("\tscope %s\n", sc.scopesym.toChars());
            }

            static void printMsg(string txt, Dsymbol s)
            {
                printf("%.*s  %s.%s, kind = '%s'\n", cast(int)msg.length, msg.ptr,
                    s.parent ? s.parent.toChars() : "", s.toChars(), s.kind());
            }
        }

        // This function is called only for unqualified lookup
        assert(!(flags & (SearchLocalsOnly | SearchImportsOnly)));

        /* If ident is "start at module scope", only look at module scope
         */
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
                    //printMsg("\tfound", s);
                    if (pscopesym)
                        *pscopesym = sc.scopesym;
                    return s;
                }
            }
            return null;
        }

        Dsymbol searchScopes(int flags)
        {
            for (Scope* sc = &this; sc; sc = sc.enclosing)
            {
                assert(sc != sc.enclosing);
                if (!sc.scopesym)
                    continue;
                //printf("\tlooking in scopesym '%s', kind = '%s', flags = x%x\n", sc.scopesym.toChars(), sc.scopesym.kind(), flags);

                if (sc.scopesym.isModule())
                    flags |= SearchUnqualifiedModule;        // tell Module.search() that SearchLocalsOnly is to be obeyed

                if (Dsymbol s = sc.scopesym.search(loc, ident, flags))
                {
                    if (!(flags & (SearchImportsOnly | IgnoreErrors)) &&
                        ident == Id.length && sc.scopesym.isArrayScopeSymbol() &&
                        sc.enclosing && sc.enclosing.search(loc, ident, null, flags))
                    {
                        warning(s.loc, "array 'length' hides other 'length' name in outer scope");
                    }
                    //printMsg("\tfound local", s);
                    if (pscopesym)
                        *pscopesym = sc.scopesym;
                    return s;
                }
                // Stop when we hit a module, but keep going if that is not just under the global scope
                if (sc.scopesym.isModule() && !(sc.enclosing && !sc.enclosing.enclosing))
                    break;
            }
            return null;
        }

        if (this.flags & SCOPEignoresymbolvisibility)
            flags |= IgnoreSymbolVisibility;

        Dsymbol sold = void;
        if (global.params.bug10378 || global.params.check10378)
        {
            sold = searchScopes(flags | IgnoreSymbolVisibility);
            if (!global.params.check10378)
                return sold;

            if (ident == Id.dollar) // Bugzilla 15825
                return sold;

            // Search both ways
        }

        // First look in local scopes
        Dsymbol s = searchScopes(flags | SearchLocalsOnly);
        version (LOGSEARCH) if (s) printMsg("-Scope.search() found local", s);
        if (!s)
        {
            // Second look in imported modules
            s = searchScopes(flags | SearchImportsOnly);
            version (LOGSEARCH) if (s) printMsg("-Scope.search() found import", s);

            /** Still find private symbols, so that symbols that weren't access
             * checked by the compiler remain usable.  Once the deprecation is over,
             * this should be moved to search_correct instead.
             */
            if (!s && !(flags & IgnoreSymbolVisibility))
            {
                s = searchScopes(flags | SearchLocalsOnly | IgnoreSymbolVisibility);
                if (!s)
                    s = searchScopes(flags | SearchImportsOnly | IgnoreSymbolVisibility);

                if (s && !(flags & IgnoreErrors))
                    .deprecation(loc, "%s is not visible from module %s", s.toPrettyChars(), _module.toChars());
                version (LOGSEARCH) if (s) printMsg("-Scope.search() found imported private symbol", s);
            }
        }
        if (global.params.check10378)
        {
            alias snew = s;
            if (sold !is snew)
                deprecation10378(loc, sold, snew);
            if (global.params.bug10378)
                s = sold;
        }
        return s;
    }

    /* A helper function to show deprecation message for new name lookup rule.
     */
    extern (C++) static void deprecation10378(Loc loc, Dsymbol sold, Dsymbol snew)
    {
        // Bugzilla 15857
        //
        // The overloadset found via the new lookup rules is either
        // equal or a subset of the overloadset found via the old
        // lookup rules, so it suffices to compare the dimension to
        // check for equality.
        OverloadSet osold, osnew;
        if (sold && (osold = sold.isOverloadSet()) !is null &&
            snew && (osnew = snew.isOverloadSet()) !is null &&
            osold.a.dim == osnew.a.dim)
            return;

        OutBuffer buf;
        buf.writestring("local import search method found ");
        if (osold)
            buf.printf("%s %s (%d overloads)", sold.kind(), sold.toPrettyChars(), cast(int) osold.a.dim);
        else if (sold)
            buf.printf("%s %s", sold.kind(), sold.toPrettyChars());
        else
            buf.writestring("nothing");
        buf.writestring(" instead of ");
        if (osnew)
            buf.printf("%s %s (%d overloads)", snew.kind(), snew.toPrettyChars(), cast(int) osnew.a.dim);
        else if (snew)
            buf.printf("%s %s", snew.kind(), snew.toPrettyChars());
        else
            buf.writestring("nothing");

        deprecation(loc, buf.peekString());
    }

    extern (C++) Dsymbol search_correct(Identifier ident)
    {
        if (global.gag)
            return null; // don't do it for speculative compiles; too time consuming

        /************************************************
         * Given the failed search attempt, try to find
         * one with a close spelling.
         */
        extern (D) void* scope_search_fp(const(char)* seed, ref int cost)
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
            Scope* sc = &this;
            Module.clearCache();
            Dsymbol scopesym = null;
            Dsymbol s = sc.search(Loc(), id, &scopesym, IgnoreErrors);
            if (s)
            {
                for (cost = 0; sc; sc = sc.enclosing, ++cost)
                    if (sc.scopesym == scopesym)
                        break;
                if (scopesym != s.parent)
                {
                    ++cost; // got to the symbol through an import
                    if (s.prot().kind == PROTprivate)
                        return null;
                }
            }
            return cast(void*)s;
        }

        return cast(Dsymbol)speller(ident.toChars(), &scope_search_fp, idchars);
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
            //    assert(0);
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
        this.aligndecl = sc.aligndecl;
        this.func = sc.func;
        this.slabel = sc.slabel;
        this.linkage = sc.linkage;
        this.cppmangle = sc.cppmangle;
        this.inlining = sc.inlining;
        this.protection = sc.protection;
        this.explicitProtection = sc.explicitProtection;
        this.stc = sc.stc;
        this.depdecl = sc.depdecl;
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

    structalign_t alignment()
    {
        if (aligndecl)
            return aligndecl.getAlignment();
        else
            return STRUCTALIGN_DEFAULT;
    }
}
