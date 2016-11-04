/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2016 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(DMDSRC _declaration.d)
 */

module ddmd.declaration;

import core.stdc.stdio;
import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dcast;
import ddmd.dclass;
import ddmd.delegatize;
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
import ddmd.init;
import ddmd.intrange;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.sideeffect;
import ddmd.target;
import ddmd.tokens;
import ddmd.visitor;

/************************************
 * Check to see the aggregate type is nested and its context pointer is
 * accessible from the current scope.
 * Returns true if error occurs.
 */
extern (C++) bool checkFrameAccess(Loc loc, Scope* sc, AggregateDeclaration ad, size_t iStart = 0)
{
    Dsymbol sparent = ad.toParent2();
    Dsymbol s = sc.func;
    if (ad.isNested() && s)
    {
        //printf("ad = %p %s [%s], parent:%p\n", ad, ad.toChars(), ad.loc.toChars(), ad.parent);
        //printf("sparent = %p %s [%s], parent: %s\n", sparent, sparent.toChars(), sparent.loc.toChars(), sparent.parent,toChars());
        if (checkNestedRef(s, sparent))
        {
            error(loc, "cannot access frame pointer of %s", ad.toPrettyChars());
            return true;
        }
    }

    bool result = false;
    for (size_t i = iStart; i < ad.fields.dim; i++)
    {
        VarDeclaration vd = ad.fields[i];
        Type tb = vd.type.baseElemOf();
        if (tb.ty == Tstruct)
        {
            result |= checkFrameAccess(loc, sc, (cast(TypeStruct)tb).sym);
        }
    }
    return result;
}

/******************************************
 */
extern (C++) void ObjectNotFound(Identifier id)
{
    Type.error(Loc(), "%s not found. object.d may be incorrectly installed or corrupt.", id.toChars());
    fatal();
}

enum STCundefined           = 0L;
enum STCstatic              = (1L << 0);
enum STCextern              = (1L << 1);
enum STCconst               = (1L << 2);
enum STCfinal               = (1L << 3);
enum STCabstract            = (1L << 4);
enum STCparameter           = (1L << 5);
enum STCfield               = (1L << 6);
enum STCoverride            = (1L << 7);
enum STCauto                = (1L << 8);
enum STCsynchronized        = (1L << 9);
enum STCdeprecated          = (1L << 10);
enum STCin                  = (1L << 11);   // in parameter
enum STCout                 = (1L << 12);   // out parameter
enum STClazy                = (1L << 13);   // lazy parameter
enum STCforeach             = (1L << 14);   // variable for foreach loop
//                            (1L << 15)
enum STCvariadic            = (1L << 16);   // variadic function argument
enum STCctorinit            = (1L << 17);   // can only be set inside constructor
enum STCtemplateparameter   = (1L << 18);   // template parameter
enum STCscope               = (1L << 19);
enum STCimmutable           = (1L << 20);
enum STCref                 = (1L << 21);
enum STCinit                = (1L << 22);   // has explicit initializer
enum STCmanifest            = (1L << 23);   // manifest constant
enum STCnodtor              = (1L << 24);   // don't run destructor
enum STCnothrow             = (1L << 25);   // never throws exceptions
enum STCpure                = (1L << 26);   // pure function
enum STCtls                 = (1L << 27);   // thread local
enum STCalias               = (1L << 28);   // alias parameter
enum STCshared              = (1L << 29);   // accessible from multiple threads
enum STCgshared             = (1L << 30);   // accessible from multiple threads, but not typed as "shared"
enum STCwild                = (1L << 31);   // for "wild" type constructor
enum STCproperty            = (1L << 32);
enum STCsafe                = (1L << 33);
enum STCtrusted             = (1L << 34);
enum STCsystem              = (1L << 35);
enum STCctfe                = (1L << 36);   // can be used in CTFE, even if it is static
enum STCdisable             = (1L << 37);   // for functions that are not callable
enum STCresult              = (1L << 38);   // for result variables passed to out contracts
enum STCnodefaultctor       = (1L << 39);   // must be set inside constructor
enum STCtemp                = (1L << 40);   // temporary variable
enum STCrvalue              = (1L << 41);   // force rvalue for variables
enum STCnogc                = (1L << 42);   // @nogc
enum STCvolatile            = (1L << 43);   // destined for volatile in the back end
enum STCreturn              = (1L << 44);   // 'return ref' for function parameters
enum STCautoref             = (1L << 45);   // Mark for the already deduced 'auto ref' parameter
enum STCinference           = (1L << 46);   // do attribute inference
enum STCexptemp             = (1L << 47);   // temporary variable that has lifetime restricted to an expression

enum STC_TYPECTOR = (STCconst | STCimmutable | STCshared | STCwild);
enum STC_FUNCATTR = (STCref | STCnothrow | STCnogc | STCpure | STCproperty | STCsafe | STCtrusted | STCsystem);

extern (C++) __gshared const(StorageClass) STCStorageClass =
    (STCauto | STCscope | STCstatic | STCextern | STCconst | STCfinal | STCabstract | STCsynchronized | STCdeprecated | STCoverride | STClazy | STCalias | STCout | STCin | STCmanifest | STCimmutable | STCshared | STCwild | STCnothrow | STCnogc | STCpure | STCref | STCtls | STCgshared | STCproperty | STCsafe | STCtrusted | STCsystem | STCdisable);

struct Match
{
    int count;              // number of matches found
    MATCH last;             // match level of lastf
    FuncDeclaration lastf;  // last matching function we found
    FuncDeclaration nextf;  // current matching function
    FuncDeclaration anyf;   // pick a func, any func, to use for error recovery
}

/***********************************************************
 */
extern (C++) abstract class Declaration : Dsymbol
{
    Type type;
    Type originalType;  // before semantic analysis
    StorageClass storage_class;
    Prot protection;
    LINK linkage;
    int inuse;          // used to detect cycles

    // overridden symbol with pragma(mangle, "...")
    const(char)* mangleOverride;

    final extern (D) this(Identifier id)
    {
        super(id);
        storage_class = STCundefined;
        protection = Prot(PROTundefined);
        linkage = LINKdefault;
    }

    override void semantic(Scope* sc)
    {
    }

    override const(char)* kind() const
    {
        return "declaration";
    }

    override final d_uns64 size(Loc loc)
    {
        assert(type);
        return type.size();
    }

    /*************************************
     * Check to see if declaration can be modified in this context (sc).
     * Issue error if not.
     */
    final int checkModify(Loc loc, Scope* sc, Type t, Expression e1, int flag)
    {
        VarDeclaration v = isVarDeclaration();
        if (v && v.canassign)
            return 2;

        if (isParameter() || isResult())
        {
            for (Scope* scx = sc; scx; scx = scx.enclosing)
            {
                if (scx.func == parent && (scx.flags & SCOPEcontract))
                {
                    const(char)* s = isParameter() && parent.ident != Id.ensure ? "parameter" : "result";
                    if (!flag)
                        error(loc, "cannot modify %s '%s' in contract", s, toChars());
                    return 2; // do not report type related errors
                }
            }
        }

        if (v && (isCtorinit() || isField()))
        {
            // It's only modifiable if inside the right constructor
            if ((storage_class & (STCforeach | STCref)) == (STCforeach | STCref))
                return 2;
            return modifyFieldVar(loc, sc, v, e1) ? 2 : 1;
        }
        return 1;
    }

    override final Dsymbol search(Loc loc, Identifier ident, int flags = SearchLocalsOnly)
    {
        Dsymbol s = Dsymbol.search(loc, ident, flags);
        if (!s && type)
        {
            s = type.toDsymbol(_scope);
            if (s)
                s = s.search(loc, ident, flags);
        }
        return s;
    }

    final bool isStatic()
    {
        return (storage_class & STCstatic) != 0;
    }

    bool isDelete()
    {
        return false;
    }

    bool isDataseg()
    {
        return false;
    }

    bool isThreadlocal()
    {
        return false;
    }

    bool isCodeseg()
    {
        return false;
    }

    final bool isCtorinit()
    {
        return (storage_class & STCctorinit) != 0;
    }

    final bool isFinal()
    {
        return (storage_class & STCfinal) != 0;
    }

    final bool isAbstract()
    {
        return (storage_class & STCabstract) != 0;
    }

    final bool isConst()
    {
        return (storage_class & STCconst) != 0;
    }

    final bool isImmutable()
    {
        return (storage_class & STCimmutable) != 0;
    }

    final bool isWild()
    {
        return (storage_class & STCwild) != 0;
    }

    final bool isAuto()
    {
        return (storage_class & STCauto) != 0;
    }

    final bool isScope()
    {
        return (storage_class & STCscope) != 0;
    }

    final bool isSynchronized()
    {
        return (storage_class & STCsynchronized) != 0;
    }

    final bool isParameter()
    {
        return (storage_class & STCparameter) != 0;
    }

    override final bool isDeprecated()
    {
        return (storage_class & STCdeprecated) != 0;
    }

    final bool isOverride()
    {
        return (storage_class & STCoverride) != 0;
    }

    final bool isResult()
    {
        return (storage_class & STCresult) != 0;
    }

    final bool isField()
    {
        return (storage_class & STCfield) != 0;
    }

    final bool isIn()
    {
        return (storage_class & STCin) != 0;
    }

    final bool isOut()
    {
        return (storage_class & STCout) != 0;
    }

    final bool isRef()
    {
        return (storage_class & STCref) != 0;
    }

    override final Prot prot()
    {
        return protection;
    }

    override final inout(Declaration) isDeclaration() inout
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
extern (C++) final class TupleDeclaration : Declaration
{
    Objects* objects;
    bool isexp;             // true: expression tuple
    TypeTuple tupletype;    // !=null if this is a type tuple

    extern (D) this(Loc loc, Identifier id, Objects* objects)
    {
        super(id);
        this.loc = loc;
        this.objects = objects;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(0);
    }

    override const(char)* kind() const
    {
        return "tuple";
    }

    override Type getType()
    {
        /* If this tuple represents a type, return that type
         */

        //printf("TupleDeclaration::getType() %s\n", toChars());
        if (isexp)
            return null;
        if (!tupletype)
        {
            /* It's only a type tuple if all the Object's are types
             */
            for (size_t i = 0; i < objects.dim; i++)
            {
                RootObject o = (*objects)[i];
                if (o.dyncast() != DYNCAST_TYPE)
                {
                    //printf("\tnot[%d], %p, %d\n", i, o, o->dyncast());
                    return null;
                }
            }

            /* We know it's a type tuple, so build the TypeTuple
             */
            Types* types = cast(Types*)objects;
            auto args = new Parameters();
            args.setDim(objects.dim);
            OutBuffer buf;
            int hasdeco = 1;
            for (size_t i = 0; i < types.dim; i++)
            {
                Type t = (*types)[i];
                //printf("type = %s\n", t->toChars());
                version (none)
                {
                    buf.printf("_%s_%d", ident.toChars(), i);
                    const len = buf.offset;
                    const name = cast(const(char)*)buf.extractData();
                    auto id = Identifier.idPool(name, len);
                    auto arg = new Parameter(STCin, t, id, null);
                }
                else
                {
                    auto arg = new Parameter(0, t, null, null);
                }
                (*args)[i] = arg;
                if (!t.deco)
                    hasdeco = 0;
            }

            tupletype = new TypeTuple(args);
            if (hasdeco)
                return tupletype.semantic(Loc(), null);
        }
        return tupletype;
    }

    override Dsymbol toAlias2()
    {
        //printf("TupleDeclaration::toAlias2() '%s' objects = %s\n", toChars(), objects->toChars());
        for (size_t i = 0; i < objects.dim; i++)
        {
            RootObject o = (*objects)[i];
            if (Dsymbol s = isDsymbol(o))
            {
                s = s.toAlias2();
                (*objects)[i] = s;
            }
        }
        return this;
    }

    override bool needThis()
    {
        //printf("TupleDeclaration::needThis(%s)\n", toChars());
        for (size_t i = 0; i < objects.dim; i++)
        {
            RootObject o = (*objects)[i];
            if (o.dyncast() == DYNCAST_EXPRESSION)
            {
                Expression e = cast(Expression)o;
                if (e.op == TOKdsymbol)
                {
                    DsymbolExp ve = cast(DsymbolExp)e;
                    Declaration d = ve.s.isDeclaration();
                    if (d && d.needThis())
                    {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    override inout(TupleDeclaration) isTupleDeclaration() inout
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
extern (C++) final class AliasDeclaration : Declaration
{
    Dsymbol aliassym;
    Dsymbol overnext;   // next in overload list
    Dsymbol _import;    // !=null if unresolved internal alias for selective import

    extern (D) this(Loc loc, Identifier id, Type type)
    {
        super(id);
        //printf("AliasDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
        //printf("type = '%s'\n", type->toChars());
        this.loc = loc;
        this.type = type;
        assert(type);
    }

    extern (D) this(Loc loc, Identifier id, Dsymbol s)
    {
        super(id);
        //printf("AliasDeclaration(id = '%s', s = %p)\n", id->toChars(), s);
        assert(s != this);
        this.loc = loc;
        this.aliassym = s;
        assert(s);
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("AliasDeclaration::syntaxCopy()\n");
        assert(!s);
        AliasDeclaration sa = type ? new AliasDeclaration(loc, ident, type.syntaxCopy()) : new AliasDeclaration(loc, ident, aliassym.syntaxCopy(null));
        sa.storage_class = storage_class;
        return sa;
    }

    override void semantic(Scope* sc)
    {
        if (semanticRun >= PASSsemanticdone)
            return;
        assert(semanticRun <= PASSsemantic);

        storage_class |= sc.stc & STCdeprecated;
        protection = sc.protection;
        userAttribDecl = sc.userAttribDecl;

        if (!sc.func && inNonRoot())
            return;

        aliasSemantic(sc);
    }

    final void aliasSemantic(Scope* sc)
    {
        //printf("AliasDeclaration::semantic() %s\n", toChars());
        if (aliassym)
        {
            auto fd = aliassym.isFuncLiteralDeclaration();
            auto td = aliassym.isTemplateDeclaration();
            if (fd || td && td.literal)
            {
                if (fd && fd.semanticRun >= PASSsemanticdone)
                    return;

                Expression e = new FuncExp(loc, aliassym);
                e = e.semantic(sc);
                if (e.op == TOKfunction)
                {
                    FuncExp fe = cast(FuncExp)e;
                    aliassym = fe.td ? cast(Dsymbol)fe.td : fe.fd;
                }
                else
                {
                    aliassym = null;
                    type = Type.terror;
                }
                return;
            }

            if (aliassym.isTemplateInstance())
                aliassym.semantic(sc);
            return;
        }
        inuse = 1;

        // Given:
        //  alias foo.bar.abc def;
        // it is not knowable from the syntax whether this is an alias
        // for a type or an alias for a symbol. It is up to the semantic()
        // pass to distinguish.
        // If it is a type, then type is set and getType() will return that
        // type. If it is a symbol, then aliassym is set and type is NULL -
        // toAlias() will return aliasssym.

        uint errors = global.errors;
        Type oldtype = type;

        // Ungag errors when not instantiated DeclDefs scope alias
        auto ungag = Ungag(global.gag);
        //printf("%s parent = %s, gag = %d, instantiated = %d\n", toChars(), parent, global.gag, isInstantiated());
        if (parent && global.gag && !isInstantiated() && !toParent2().isFuncDeclaration())
        {
            //printf("%s type = %s\n", toPrettyChars(), type->toChars());
            global.gag = 0;
        }

        /* This section is needed because Type.resolve() will:
         *   const x = 3;
         *   alias y = x;
         * try to convert identifier x to 3.
         */
        auto s = type.toDsymbol(sc);
        if (errors != global.errors)
        {
            s = null;
            type = Type.terror;
        }
        if (s && s == this)
        {
            error("cannot resolve");
            s = null;
            type = Type.terror;
        }
        if (!s || !s.isEnumMember())
        {
            Type t;
            Expression e;
            Scope* sc2 = sc;
            if (storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCdisable))
            {
                // For 'ref' to be attached to function types, and picked
                // up by Type.resolve(), it has to go into sc.
                sc2 = sc.push();
                sc2.stc |= storage_class & (STCref | STCnothrow | STCnogc | STCpure | STCshared | STCdisable);
            }
            type = type.addSTC(storage_class);
            type.resolve(loc, sc2, &e, &t, &s);
            if (sc2 != sc)
                sc2.pop();

            if (e)  // Try to convert Expression to Dsymbol
            {
                s = getDsymbol(e);
                if (!s)
                {
                    if (e.op != TOKerror)
                        error("cannot alias an expression %s", e.toChars());
                    t = Type.terror;
                }
            }
            type = t;
        }
        if (s == this)
        {
            assert(global.errors);
            type = Type.terror;
            s = null;
        }
        if (!s) // it's a type alias
        {
            //printf("alias %s resolved to type %s\n", toChars(), type.toChars());
            type = type.semantic(loc, sc);
            aliassym = null;
        }
        else    // it's a symbolic alias
        {
            //printf("alias %s resolved to %s %s\n", toChars(), s.kind(), s.toChars());
            type = null;
            aliassym = s;
        }
        if (global.gag && errors != global.errors)
        {
            type = oldtype;
            aliassym = null;
        }
        inuse = 0;
        semanticRun = PASSsemanticdone;

        if (auto sx = overnext)
        {
            overnext = null;
            if (!overloadInsert(sx))
                ScopeDsymbol.multiplyDefined(Loc(), sx, this);
        }
    }

    override bool overloadInsert(Dsymbol s)
    {
        //printf("[%s] AliasDeclaration::overloadInsert('%s') s = %s %s @ [%s]\n",
        //       loc.toChars(), toChars(), s.kind(), s.toChars(), s.loc.toChars());

        /** Aliases aren't overloadable themselves, but if their Aliasee is
         *  overloadable they are converted to an overloadable Alias (either
         *  FuncAliasDeclaration or OverDeclaration).
         *
         *  This is done by moving the Aliasee into such an overloadable alias
         *  which is then used to replace the existing Aliasee. The original
         *  Alias (_this_) remains a useless shell.
         *
         *  This is a horrible mess. It was probably done to avoid replacing
         *  existing AST nodes and references, but it needs a major
         *  simplification b/c it's too complex to maintain.
         *
         *  A simpler approach might be to merge any colliding symbols into a
         *  simple Overload class (an array) and then later have that resolve
         *  all collisions.
         */
        if (semanticRun >= PASSsemanticdone)
        {
            /* Semantic analysis is already finished, and the aliased entity
             * is not overloadable.
             */
            if (type)
                return false;

            /* When s is added in member scope by static if, mixin("code") or others,
             * aliassym is determined already. See the case in: test/compilable/test61.d
             */
            auto sa = aliassym.toAlias();
            if (auto fd = sa.isFuncDeclaration())
            {
                auto fa = new FuncAliasDeclaration(ident, fd);
                fa.protection = protection;
                fa.parent = parent;
                aliassym = fa;
                return aliassym.overloadInsert(s);
            }
            if (auto td = sa.isTemplateDeclaration())
            {
                auto od = new OverDeclaration(ident, td);
                od.protection = protection;
                od.parent = parent;
                aliassym = od;
                return aliassym.overloadInsert(s);
            }
            if (auto od = sa.isOverDeclaration())
            {
                if (sa.ident != ident || sa.parent != parent)
                {
                    od = new OverDeclaration(ident, od);
                    od.protection = protection;
                    od.parent = parent;
                    aliassym = od;
                }
                return od.overloadInsert(s);
            }
            if (auto os = sa.isOverloadSet())
            {
                if (sa.ident != ident || sa.parent != parent)
                {
                    os = new OverloadSet(ident, os);
                    // TODO: protection is lost here b/c OverloadSets have no protection attribute
                    // Might no be a practical issue, b/c the code below fails to resolve the overload anyhow.
                    // ----
                    // module os1;
                    // import a, b;
                    // private alias merged = foo; // private alias to overload set of a.foo and b.foo
                    // ----
                    // module os2;
                    // import a, b;
                    // public alias merged = bar; // public alias to overload set of a.bar and b.bar
                    // ----
                    // module bug;
                    // import os1, os2;
                    // void test() { merged(123); } // should only look at os2.merged
                    //
                    // os.protection = protection;
                    os.parent = parent;
                    aliassym = os;
                }
                os.push(s);
                return true;
            }
            return false;
        }

        /* Don't know yet what the aliased symbol is, so assume it can
         * be overloaded and check later for correctness.
         */
        if (overnext)
            return overnext.overloadInsert(s);
        if (s is this)
            return true;
        overnext = s;
        return true;
    }

    override const(char)* kind() const
    {
        return "alias";
    }

    override Type getType()
    {
        if (type)
            return type;
        return toAlias().getType();
    }

    override Dsymbol toAlias()
    {
        //printf("[%s] AliasDeclaration::toAlias('%s', this = %p, aliassym = %p, kind = '%s', inuse = %d)\n",
        //    loc.toChars(), toChars(), this, aliassym, aliassym ? aliassym.kind() : "", inuse);
        assert(this != aliassym);
        //static int count; if (++count == 10) *(char*)0=0;
        if (inuse == 1 && type && _scope)
        {
            inuse = 2;
            uint olderrors = global.errors;
            Dsymbol s = type.toDsymbol(_scope);
            //printf("[%s] type = %s, s = %p, this = %p\n", loc.toChars(), type->toChars(), s, this);
            if (global.errors != olderrors)
                goto Lerr;
            if (s)
            {
                s = s.toAlias();
                if (global.errors != olderrors)
                    goto Lerr;
                aliassym = s;
                inuse = 0;
            }
            else
            {
                Type t = type.semantic(loc, _scope);
                if (t.ty == Terror)
                    goto Lerr;
                if (global.errors != olderrors)
                    goto Lerr;
                //printf("t = %s\n", t->toChars());
                inuse = 0;
            }
        }
        if (inuse)
        {
            error("recursive alias declaration");

        Lerr:
            // Avoid breaking "recursive alias" state during errors gagged
            if (global.gag)
                return this;
            aliassym = new AliasDeclaration(loc, ident, Type.terror);
            type = Type.terror;
            return aliassym;
        }

        if (semanticRun >= PASSsemanticdone)
        {
            // semantic is already done.

            // Do not see aliassym !is null, because of lambda aliases.

            // Do not see type.deco !is null, even so "alias T = const int;` needs
            // semantic analysis to take the storage class `const` as type qualifier.
        }
        else
        {
            if (_import && _import._scope)
            {
                /* If this is an internal alias for selective/renamed import,
                 * load the module first.
                 */
                _import.semantic(null);
            }
            if (_scope)
            {
                aliasSemantic(_scope);
            }
        }

        inuse = 1;
        Dsymbol s = aliassym ? aliassym.toAlias() : this;
        inuse = 0;
        return s;
    }

    override Dsymbol toAlias2()
    {
        if (inuse)
        {
            error("recursive alias declaration");
            return this;
        }
        inuse = 1;
        Dsymbol s = aliassym ? aliassym.toAlias2() : this;
        inuse = 0;
        return s;
    }

    override bool isOverloadable()
    {
        // assume overloadable until alias is resolved
        return semanticRun < PASSsemanticdone ||
            aliassym && aliassym.isOverloadable();
    }

    override inout(AliasDeclaration) isAliasDeclaration() inout
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
extern (C++) final class OverDeclaration : Declaration
{
    Dsymbol overnext;   // next in overload list
    Dsymbol aliassym;
    bool hasOverloads;

    extern (D) this(Identifier ident, Dsymbol s, bool hasOverloads = true)
    {
        super(ident);
        this.aliassym = s;
        this.hasOverloads = hasOverloads;
        if (hasOverloads)
        {
            if (OverDeclaration od = aliassym.isOverDeclaration())
                this.hasOverloads = od.hasOverloads;
        }
        else
        {
            // for internal use
            assert(!aliassym.isOverDeclaration());
        }
    }

    override const(char)* kind() const
    {
        return "overload alias"; // todo
    }

    override void semantic(Scope* sc)
    {
    }

    override bool equals(RootObject o)
    {
        if (this == o)
            return true;

        Dsymbol s = isDsymbol(o);
        if (!s)
            return false;

        OverDeclaration od1 = this;
        if (OverDeclaration od2 = s.isOverDeclaration())
        {
            return od1.aliassym.equals(od2.aliassym) && od1.hasOverloads == od2.hasOverloads;
        }
        if (aliassym == s)
        {
            if (hasOverloads)
                return true;
            if (FuncDeclaration fd = s.isFuncDeclaration())
            {
                return fd.isUnique() !is null;
            }
            if (TemplateDeclaration td = s.isTemplateDeclaration())
            {
                return td.overnext is null;
            }
        }
        return false;
    }

    override bool overloadInsert(Dsymbol s)
    {
        //printf("OverDeclaration::overloadInsert('%s') aliassym = %p, overnext = %p\n", s->toChars(), aliassym, overnext);
        if (overnext)
            return overnext.overloadInsert(s);
        if (s == this)
            return true;
        overnext = s;
        return true;
    }

    override bool isOverloadable()
    {
        return true;
    }

    Dsymbol isUnique()
    {
        if (!hasOverloads)
        {
            if (aliassym.isFuncDeclaration() ||
                aliassym.isTemplateDeclaration())
            {
                return aliassym;
            }
        }

        Dsymbol result = null;
        overloadApply(aliassym, (Dsymbol s)
        {
            if (result)
            {
                result = null;
                return 1; // ambiguous, done
            }
            else
            {
                result = s;
                return 0;
            }
        });
        return result;
    }

    override inout(OverDeclaration) isOverDeclaration() inout
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
extern (C++) class VarDeclaration : Declaration
{
    Initializer _init;
    uint offset;
    FuncDeclarations nestedrefs;    // referenced by these lexically nested functions
    bool isargptr;                  // if parameter that _argptr points to
    structalign_t alignment;
    bool ctorinit;                  // it has been initialized in a ctor

    // Both these mean the var is not rebindable once assigned,
    // and the destructor gets run when it goes out of scope
    bool onstack;                   // it is a class that was allocated on the stack
    bool mynew;                     // it is a class new'd with custom operator new

    int canassign;                  // it can be assigned to
    bool overlapped;                // if it is a field and has overlapping
    bool overlapUnsafe;             // if it is an overlapping field and the overlaps are unsafe
    ubyte isdataseg;                // private data for isDataseg 0 unset, 1 true, 2 false
    Dsymbol aliassym;               // if redone as alias to another symbol
    VarDeclaration lastVar;         // Linked list of variables for goto-skips-init detection
    uint endlinnum;                 // line number of end of scope that this var lives in

    // When interpreting, these point to the value (NULL if value not determinable)
    // The index of this variable on the CTFE stack, -1 if not allocated
    int ctfeAdrOnStack;

    // if !=NULL, rundtor is tested at runtime to see
    // if the destructor should be run. Used to prevent
    // dtor calls on postblitted vars
    VarDeclaration rundtor;
    Expression edtor;               // if !=null, does the destruction of the variable
    IntRange* range;                // if !=null, the variable is known to be within the range

    final extern (D) this(Loc loc, Type type, Identifier id, Initializer _init, StorageClass storage_class = STCundefined)
    {
        super(id);
        //printf("VarDeclaration('%s')\n", id->toChars());
        assert(id);
        debug
        {
            if (!type && !_init)
            {
                printf("VarDeclaration('%s')\n", id.toChars());
                //*(char*)0=0;
            }
        }
        assert(type || _init);
        this.type = type;
        this._init = _init;
        this.loc = loc;
        ctfeAdrOnStack = -1;
        this.storage_class = storage_class;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("VarDeclaration::syntaxCopy(%s)\n", toChars());
        assert(!s);
        auto v = new VarDeclaration(loc, type ? type.syntaxCopy() : null, ident, _init ? _init.syntaxCopy() : null, storage_class);
        return v;
    }

    override void semantic(Scope* sc)
    {
        version (none)
        {
            printf("VarDeclaration::semantic('%s', parent = '%s') sem = %d\n", toChars(), sc.parent ? sc.parent.toChars() : null, sem);
            printf(" type = %s\n", type ? type.toChars() : "null");
            printf(" stc = x%x\n", sc.stc);
            printf(" storage_class = x%llx\n", storage_class);
            printf("linkage = %d\n", sc.linkage);
            //if (strcmp(toChars(), "mul") == 0) assert(0);
        }
        //if (semanticRun > PASSinit)
        //    return;
        //semanticRun = PSSsemantic;

        if (semanticRun >= PASSsemanticdone)
            return;

        Scope* scx = null;
        if (_scope)
        {
            sc = _scope;
            scx = sc;
            _scope = null;
        }

        /* Pick up storage classes from context, but except synchronized,
         * override, abstract, and final.
         */
        storage_class |= (sc.stc & ~(STCsynchronized | STCoverride | STCabstract | STCfinal));
        if (storage_class & STCextern && _init)
            error("extern symbols cannot have initializers");

        userAttribDecl = sc.userAttribDecl;

        AggregateDeclaration ad = isThis();
        if (ad)
            storage_class |= ad.storage_class & STC_TYPECTOR;

        /* If auto type inference, do the inference
         */
        int inferred = 0;
        if (!type)
        {
            inuse++;

            // Infering the type requires running semantic,
            // so mark the scope as ctfe if required
            bool needctfe = (storage_class & (STCmanifest | STCstatic)) != 0;
            if (needctfe)
                sc = sc.startCTFE();

            //printf("inferring type for %s with init %s\n", toChars(), init->toChars());
            _init = _init.inferType(sc);
            type = _init.toExpression().type;
            if (needctfe)
                sc = sc.endCTFE();

            inuse--;
            inferred = 1;

            /* This is a kludge to support the existing syntax for RAII
             * declarations.
             */
            storage_class &= ~STCauto;
            originalType = type.syntaxCopy();
        }
        else
        {
            if (!originalType)
                originalType = type.syntaxCopy();

            /* Prefix function attributes of variable declaration can affect
             * its type:
             *      pure nothrow void function() fp;
             *      static assert(is(typeof(fp) == void function() pure nothrow));
             */
            Scope* sc2 = sc.push();
            sc2.stc |= (storage_class & STC_FUNCATTR);
            inuse++;
            type = type.semantic(loc, sc2);
            inuse--;
            sc2.pop();
        }
        //printf(" semantic type = %s\n", type ? type->toChars() : "null");
        if (type.ty == Terror)
            errors = true;

        type.checkDeprecated(loc, sc);
        linkage = sc.linkage;
        this.parent = sc.parent;
        //printf("this = %p, parent = %p, '%s'\n", this, parent, parent->toChars());
        protection = sc.protection;

        /* If scope's alignment is the default, use the type's alignment,
         * otherwise the scope overrrides.
         */
        alignment = sc.alignment();
        if (alignment == STRUCTALIGN_DEFAULT)
            alignment = type.alignment(); // use type's alignment

        //printf("sc->stc = %x\n", sc->stc);
        //printf("storage_class = x%x\n", storage_class);

        if (global.params.vcomplex)
            type.checkComplexTransition(loc);

        // Calculate type size + safety checks
        if (sc.func && !sc.intypeof)
        {
            if (storage_class & STCgshared && !isMember())
            {
                if (sc.func.setUnsafe())
                    error("__gshared not allowed in safe functions; use shared");
            }
        }

        Dsymbol parent = toParent();

        Type tb = type.toBasetype();
        Type tbn = tb.baseElemOf();
        if (tb.ty == Tvoid && !(storage_class & STClazy))
        {
            if (inferred)
            {
                error("type %s is inferred from initializer %s, and variables cannot be of type void", type.toChars(), _init.toChars());
            }
            else
                error("variables cannot be of type void");
            type = Type.terror;
            tb = type;
        }
        if (tb.ty == Tfunction)
        {
            error("cannot be declared to be a function");
            type = Type.terror;
            tb = type;
        }
        if (tb.ty == Tstruct)
        {
            TypeStruct ts = cast(TypeStruct)tb;
            if (!ts.sym.members)
            {
                error("no definition of struct %s", ts.toChars());
            }
        }
        if ((storage_class & STCauto) && !inferred)
            error("storage class 'auto' has no effect if type is not inferred, did you mean 'scope'?");

        if (tb.ty == Ttuple)
        {
            /* Instead, declare variables for each of the tuple elements
             * and add those.
             */
            TypeTuple tt = cast(TypeTuple)tb;
            size_t nelems = Parameter.dim(tt.arguments);
            Expression ie = (_init && !_init.isVoidInitializer()) ? _init.toExpression() : null;
            if (ie)
                ie = ie.semantic(sc);
            if (nelems > 0 && ie)
            {
                auto iexps = new Expressions();
                iexps.push(ie);
                auto exps = new Expressions();
                for (size_t pos = 0; pos < iexps.dim; pos++)
                {
                Lexpand1:
                    Expression e = (*iexps)[pos];
                    Parameter arg = Parameter.getNth(tt.arguments, pos);
                    arg.type = arg.type.semantic(loc, sc);
                    //printf("[%d] iexps->dim = %d, ", pos, iexps->dim);
                    //printf("e = (%s %s, %s), ", Token::tochars[e->op], e->toChars(), e->type->toChars());
                    //printf("arg = (%s, %s)\n", arg->toChars(), arg->type->toChars());

                    if (e != ie)
                    {
                        if (iexps.dim > nelems)
                            goto Lnomatch;
                        if (e.type.implicitConvTo(arg.type))
                            continue;
                    }

                    if (e.op == TOKtuple)
                    {
                        TupleExp te = cast(TupleExp)e;
                        if (iexps.dim - 1 + te.exps.dim > nelems)
                            goto Lnomatch;

                        iexps.remove(pos);
                        iexps.insert(pos, te.exps);
                        (*iexps)[pos] = Expression.combine(te.e0, (*iexps)[pos]);
                        goto Lexpand1;
                    }
                    else if (isAliasThisTuple(e))
                    {
                        auto v = copyToTemp(0, "__tup", e);
                        auto ve = new VarExp(loc, v);
                        ve.type = e.type;

                        exps.setDim(1);
                        (*exps)[0] = ve;
                        expandAliasThisTuples(exps, 0);

                        for (size_t u = 0; u < exps.dim; u++)
                        {
                        Lexpand2:
                            Expression ee = (*exps)[u];
                            arg = Parameter.getNth(tt.arguments, pos + u);
                            arg.type = arg.type.semantic(loc, sc);
                            //printf("[%d+%d] exps->dim = %d, ", pos, u, exps->dim);
                            //printf("ee = (%s %s, %s), ", Token::tochars[ee->op], ee->toChars(), ee->type->toChars());
                            //printf("arg = (%s, %s)\n", arg->toChars(), arg->type->toChars());

                            size_t iexps_dim = iexps.dim - 1 + exps.dim;
                            if (iexps_dim > nelems)
                                goto Lnomatch;
                            if (ee.type.implicitConvTo(arg.type))
                                continue;

                            if (expandAliasThisTuples(exps, u) != -1)
                                goto Lexpand2;
                        }

                        if ((*exps)[0] != ve)
                        {
                            Expression e0 = (*exps)[0];
                            (*exps)[0] = new CommaExp(loc, new DeclarationExp(loc, v), e0);
                            (*exps)[0].type = e0.type;

                            iexps.remove(pos);
                            iexps.insert(pos, exps);
                            goto Lexpand1;
                        }
                    }
                }
                if (iexps.dim < nelems)
                    goto Lnomatch;

                ie = new TupleExp(_init.loc, iexps);
            }
        Lnomatch:

            if (ie && ie.op == TOKtuple)
            {
                TupleExp te = cast(TupleExp)ie;
                size_t tedim = te.exps.dim;
                if (tedim != nelems)
                {
                    .error(loc, "tuple of %d elements cannot be assigned to tuple of %d elements", cast(int)tedim, cast(int)nelems);
                    for (size_t u = tedim; u < nelems; u++) // fill dummy expression
                        te.exps.push(new ErrorExp());
                }
            }

            auto exps = new Objects();
            exps.setDim(nelems);
            for (size_t i = 0; i < nelems; i++)
            {
                Parameter arg = Parameter.getNth(tt.arguments, i);

                OutBuffer buf;
                buf.printf("__%s_field_%llu", ident.toChars(), cast(ulong)i);
                auto id = Identifier.idPool(buf.peekSlice());

                Initializer ti;
                if (ie)
                {
                    Expression einit = ie;
                    if (ie.op == TOKtuple)
                    {
                        TupleExp te = cast(TupleExp)ie;
                        einit = (*te.exps)[i];
                        if (i == 0)
                            einit = Expression.combine(te.e0, einit);
                    }
                    ti = new ExpInitializer(einit.loc, einit);
                }
                else
                    ti = _init ? _init.syntaxCopy() : null;

                StorageClass storage_class = STCtemp | storage_class;
                if (arg.storageClass & STCparameter)
                    storage_class |= arg.storageClass;
                auto v = new VarDeclaration(loc, arg.type, id, ti, storage_class);
                //printf("declaring field %s of type %s\n", v->toChars(), v->type->toChars());
                v.semantic(sc);

                if (sc.scopesym)
                {
                    //printf("adding %s to %s\n", v->toChars(), sc->scopesym->toChars());
                    if (sc.scopesym.members)
                        // Note this prevents using foreach() over members, because the limits can change
                        sc.scopesym.members.push(v);
                }

                Expression e = new DsymbolExp(loc, v);
                (*exps)[i] = e;
            }
            auto v2 = new TupleDeclaration(loc, ident, exps);
            v2.parent = this.parent;
            v2.isexp = true;
            aliassym = v2;
            semanticRun = PASSsemanticdone;
            return;
        }

        /* Storage class can modify the type
         */
        type = type.addStorageClass(storage_class);

        /* Adjust storage class to reflect type
         */
        if (type.isConst())
        {
            storage_class |= STCconst;
            if (type.isShared())
                storage_class |= STCshared;
        }
        else if (type.isImmutable())
            storage_class |= STCimmutable;
        else if (type.isShared())
            storage_class |= STCshared;
        else if (type.isWild())
            storage_class |= STCwild;

        if (StorageClass stc = storage_class & (STCsynchronized | STCoverride | STCabstract | STCfinal))
        {
            if (stc == STCfinal)
                error("cannot be final, perhaps you meant const?");
            else
            {
                OutBuffer buf;
                stcToBuffer(&buf, stc);
                error("cannot be %s", buf.peekString());
            }
            storage_class &= ~stc; // strip off
        }

        if (storage_class & STCscope)
        {
            StorageClass stc = storage_class & (STCstatic | STCextern | STCmanifest | STCtls | STCgshared);
            if (stc)
            {
                OutBuffer buf;
                stcToBuffer(&buf, stc);
                error("cannot be 'scope' and '%s'", buf.peekString());
            }
            else if (isMember())
            {
                error("field cannot be 'scope'");
            }
            else if (!type.hasPointers())
            {
                storage_class &= ~STCscope;     // silently ignore; may occur in generic code
            }
        }

        if (storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter | STCtls | STCgshared | STCctfe))
        {
        }
        else
        {
            AggregateDeclaration aad = parent.isAggregateDeclaration();
            if (aad)
            {
                if (global.params.vfield && storage_class & (STCconst | STCimmutable) && _init && !_init.isVoidInitializer())
                {
                    const(char)* p = loc.toChars();
                    const(char)* s = (storage_class & STCimmutable) ? "immutable" : "const";
                    fprintf(global.stdmsg, "%s: %s.%s is %s field\n", p ? p : "", ad.toPrettyChars(), toChars(), s);
                }
                storage_class |= STCfield;
                if (tbn.ty == Tstruct && (cast(TypeStruct)tbn).sym.noDefaultCtor)
                {
                    if (!isThisDeclaration() && !_init)
                        aad.noDefaultCtor = true;
                }
            }

            InterfaceDeclaration id = parent.isInterfaceDeclaration();
            if (id)
            {
                error("field not allowed in interface");
            }
            else if (aad && aad.sizeok == SIZEOKdone)
            {
                error("cannot be further field because it will change the determined %s size", aad.toChars());
            }

            /* Templates cannot add fields to aggregates
             */
            TemplateInstance ti = parent.isTemplateInstance();
            if (ti)
            {
                // Take care of nested templates
                while (1)
                {
                    TemplateInstance ti2 = ti.tempdecl.parent.isTemplateInstance();
                    if (!ti2)
                        break;
                    ti = ti2;
                }
                // If it's a member template
                AggregateDeclaration ad2 = ti.tempdecl.isMember();
                if (ad2 && storage_class != STCundefined)
                {
                    error("cannot use template to add field to aggregate '%s'", ad2.toChars());
                }
            }
        }

        if ((storage_class & (STCref | STCparameter | STCforeach | STCtemp | STCresult)) == STCref && ident != Id.This)
        {
            error("only parameters or foreach declarations can be ref");
        }

        if (type.hasWild())
        {
            if (storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCfield) || isDataseg())
            {
                error("only parameters or stack based variables can be inout");
            }
            FuncDeclaration func = sc.func;
            if (func)
            {
                if (func.fes)
                    func = func.fes.func;
                bool isWild = false;
                for (FuncDeclaration fd = func; fd; fd = fd.toParent2().isFuncDeclaration())
                {
                    if ((cast(TypeFunction)fd.type).iswild)
                    {
                        isWild = true;
                        break;
                    }
                }
                if (!isWild)
                {
                    error("inout variables can only be declared inside inout functions");
                }
            }
        }

        if (!(storage_class & (STCctfe | STCref | STCresult)) && tbn.ty == Tstruct && (cast(TypeStruct)tbn).sym.noDefaultCtor)
        {
            if (!_init)
            {
                if (isField())
                {
                    /* For fields, we'll check the constructor later to make sure it is initialized
                     */
                    storage_class |= STCnodefaultctor;
                }
                else if (storage_class & STCparameter)
                {
                }
                else
                    error("default construction is disabled for type %s", type.toChars());
            }
        }

        FuncDeclaration fd = parent.isFuncDeclaration();
        if (type.isscope() && !(storage_class & STCnodtor))
        {
            if (storage_class & (STCfield | STCout | STCref | STCstatic | STCmanifest | STCtls | STCgshared) || !fd)
            {
                error("globals, statics, fields, manifest constants, ref and out parameters cannot be scope");
            }
            if (!(storage_class & STCscope))
            {
                if (!(storage_class & STCparameter) && ident != Id.withSym)
                    error("reference to scope class must be scope");
            }
        }

        // Calculate type size + safety checks
        if (sc.func && !sc.intypeof)
        {
            if (_init && _init.isVoidInitializer() && type.hasPointers()) // get type size
            {
                if (sc.func.setUnsafe())
                    error("void initializers for pointers not allowed in safe functions");
            }
            else if (!_init &&
                     !(storage_class & (STCstatic | STCextern | STCtls | STCgshared | STCmanifest | STCfield | STCparameter)) &&
                     type.hasVoidInitPointers())
            {
                if (sc.func.setUnsafe())
                    error("void initializers for pointers not allowed in safe functions");
            }
        }

        if (!_init && !fd)
        {
            // If not mutable, initializable by constructor only
            storage_class |= STCctorinit;
        }

        if (_init)
            storage_class |= STCinit; // remember we had an explicit initializer
        else if (storage_class & STCmanifest)
            error("manifest constants must have initializers");

        bool isBlit = false;
        d_uns64 sz;
        if (!_init &&
            !sc.inunion &&
            !(storage_class & (STCstatic | STCgshared | STCextern)) &&
            fd &&
            (!(storage_class & (STCfield | STCin | STCforeach | STCparameter | STCresult)) ||
             (storage_class & STCout)) &&
            (sz = type.size()) != 0)
        {
            // Provide a default initializer

            //printf("Providing default initializer for '%s'\n", toChars());
            if (sz == SIZE_INVALID && type.ty != Terror)
                error("size of type %s is invalid", type.toChars());

            Type tv = type;
            while (tv.ty == Tsarray)    // Don't skip Tenum
                tv = tv.nextOf();
            if (tv.needsNested())
            {
                /* Nested struct requires valid enclosing frame pointer.
                 * In StructLiteralExp::toElem(), it's calculated.
                 */
                assert(tbn.ty == Tstruct);
                checkFrameAccess(loc, sc, (cast(TypeStruct)tbn).sym);

                Expression e = tv.defaultInitLiteral(loc);
                e = new BlitExp(loc, new VarExp(loc, this), e);
                e = e.semantic(sc);
                _init = new ExpInitializer(loc, e);
                goto Ldtor;
            }
            if (tv.ty == Tstruct && (cast(TypeStruct)tv).sym.zeroInit == 1)
            {
                /* If a struct is all zeros, as a special case
                 * set it's initializer to the integer 0.
                 * In AssignExp::toElem(), we check for this and issue
                 * a memset() to initialize the struct.
                 * Must do same check in interpreter.
                 */
                Expression e = new IntegerExp(loc, 0, Type.tint32);
                e = new BlitExp(loc, new VarExp(loc, this), e);
                e.type = type;      // don't type check this, it would fail
                _init = new ExpInitializer(loc, e);
                goto Ldtor;
            }
            if (type.baseElemOf().ty == Tvoid)
            {
                error("%s does not have a default initializer", type.toChars());
            }
            else if (auto e = type.defaultInit(loc))
            {
                _init = new ExpInitializer(loc, e);
            }

            // Default initializer is always a blit
            isBlit = true;
        }
        if (_init)
        {
            sc = sc.push();
            sc.stc &= ~(STC_TYPECTOR | STCpure | STCnothrow | STCnogc | STCref | STCdisable);

            ExpInitializer ei = _init.isExpInitializer();
            if (ei) // Bugzilla 13424: Preset the required type to fail in FuncLiteralDeclaration::semantic3
                ei.exp = inferType(ei.exp, type);

            // If inside function, there is no semantic3() call
            if (sc.func || sc.intypeof == 1)
            {
                // If local variable, use AssignExp to handle all the various
                // possibilities.
                if (fd && !(storage_class & (STCmanifest | STCstatic | STCtls | STCgshared | STCextern)) && !_init.isVoidInitializer())
                {
                    //printf("fd = '%s', var = '%s'\n", fd->toChars(), toChars());
                    if (!ei)
                    {
                        ArrayInitializer ai = _init.isArrayInitializer();
                        Expression e;
                        if (ai && tb.ty == Taarray)
                            e = ai.toAssocArrayLiteral();
                        else
                            e = _init.toExpression();
                        if (!e)
                        {
                            // Run semantic, but don't need to interpret
                            _init = _init.semantic(sc, type, INITnointerpret);
                            e = _init.toExpression();
                            if (!e)
                            {
                                error("is not a static and cannot have static initializer");
                                return;
                            }
                        }
                        ei = new ExpInitializer(_init.loc, e);
                        _init = ei;
                    }

                    Expression exp = ei.exp;
                    Expression e1 = new VarExp(loc, this);
                    if (isBlit)
                        exp = new BlitExp(loc, e1, exp);
                    else
                        exp = new ConstructExp(loc, e1, exp);
                    canassign++;
                    exp = exp.semantic(sc);
                    canassign--;
                    exp = exp.optimize(WANTvalue);
                    if (exp.op == TOKerror)
                    {
                        _init = new ErrorInitializer();
                        ei = null;
                    }
                    else
                        ei.exp = exp;

                    if (ei && isScope())
                    {
                        Expression ex = ei.exp;
                        while (ex.op == TOKcomma)
                            ex = (cast(CommaExp)ex).e2;
                        if (ex.op == TOKblit || ex.op == TOKconstruct)
                            ex = (cast(AssignExp)ex).e2;
                        if (ex.op == TOKnew)
                        {
                            // See if initializer is a NewExp that can be allocated on the stack
                            NewExp ne = cast(NewExp)ex;
                            if (type.toBasetype().ty == Tclass)
                            {
                                if (ne.newargs && ne.newargs.dim > 1)
                                {
                                    mynew = true;
                                }
                                else
                                {
                                    ne.onstack = 1;
                                    onstack = true;
                                }
                            }
                        }
                        else if (ex.op == TOKfunction)
                        {
                            // or a delegate that doesn't escape a reference to the function
                            FuncDeclaration f = (cast(FuncExp)ex).fd;
                            f.tookAddressOf--;
                        }
                    }
                }
                else
                {
                    // Bugzilla 14166: Don't run CTFE for the temporary variables inside typeof
                    _init = _init.semantic(sc, type, sc.intypeof == 1 ? INITnointerpret : INITinterpret);
                }
            }
            else if (parent.isAggregateDeclaration())
            {
                _scope = scx ? scx : sc.copy();
                _scope.setNoFree();
            }
            else if (storage_class & (STCconst | STCimmutable | STCmanifest) || type.isConst() || type.isImmutable())
            {
                /* Because we may need the results of a const declaration in a
                 * subsequent type, such as an array dimension, before semantic2()
                 * gets ordinarily run, try to run semantic2() now.
                 * Ignore failure.
                 */
                if (!inferred)
                {
                    uint errors = global.errors;
                    inuse++;
                    if (ei)
                    {
                        Expression exp = ei.exp.syntaxCopy();

                        bool needctfe = isDataseg() || (storage_class & STCmanifest);
                        if (needctfe)
                            sc = sc.startCTFE();
                        exp = exp.semantic(sc);
                        exp = resolveProperties(sc, exp);
                        if (needctfe)
                            sc = sc.endCTFE();

                        Type tb2 = type.toBasetype();
                        Type ti = exp.type.toBasetype();

                        /* The problem is the following code:
                         *  struct CopyTest {
                         *     double x;
                         *     this(double a) { x = a * 10.0;}
                         *     this(this) { x += 2.0; }
                         *  }
                         *  const CopyTest z = CopyTest(5.3);  // ok
                         *  const CopyTest w = z;              // not ok, postblit not run
                         *  static assert(w.x == 55.0);
                         * because the postblit doesn't get run on the initialization of w.
                         */
                        if (ti.ty == Tstruct)
                        {
                            StructDeclaration sd = (cast(TypeStruct)ti).sym;
                            /* Look to see if initializer involves a copy constructor
                             * (which implies a postblit)
                             */
                            // there is a copy constructor
                            // and exp is the same struct
                            if (sd.postblit && tb2.toDsymbol(null) == sd)
                            {
                                // The only allowable initializer is a (non-copy) constructor
                                if (exp.isLvalue())
                                    error("of type struct %s uses this(this), which is not allowed in static initialization", tb2.toChars());
                            }
                        }
                        ei.exp = exp;
                    }
                    _init = _init.semantic(sc, type, INITinterpret);
                    inuse--;
                    if (global.errors > errors)
                    {
                        _init = new ErrorInitializer();
                        type = Type.terror;
                    }
                }
                else
                {
                    _scope = scx ? scx : sc.copy();
                    _scope.setNoFree();
                }
            }
            sc = sc.pop();
        }

    Ldtor:
        /* Build code to execute destruction, if necessary
         */
        edtor = callScopeDtor(sc);
        if (edtor)
        {
            if (sc.func && storage_class & (STCstatic | STCgshared))
                edtor = edtor.semantic(sc._module._scope);
            else
                edtor = edtor.semantic(sc);

            version (none)
            {
                // currently disabled because of std.stdio.stdin, stdout and stderr
                if (isDataseg() && !(storage_class & STCextern))
                    error("static storage variables cannot have destructors");
            }
        }

        semanticRun = PASSsemanticdone;

        if (type.toBasetype().ty == Terror)
            errors = true;

        if(sc.scopesym && !sc.scopesym.isAggregateDeclaration())
        {
            for (ScopeDsymbol sym = sc.scopesym; sym && endlinnum == 0;
                 sym = sym.parent ? sym.parent.isScopeDsymbol() : null)
                endlinnum = sym.endlinnum;
        }
    }

    override final void setFieldOffset(AggregateDeclaration ad, uint* poffset, bool isunion)
    {
        //printf("VarDeclaration::setFieldOffset(ad = %s) %s\n", ad.toChars(), toChars());

        if (aliassym)
        {
            // If this variable was really a tuple, set the offsets for the tuple fields
            TupleDeclaration v2 = aliassym.isTupleDeclaration();
            assert(v2);
            for (size_t i = 0; i < v2.objects.dim; i++)
            {
                RootObject o = (*v2.objects)[i];
                assert(o.dyncast() == DYNCAST_EXPRESSION);
                Expression e = cast(Expression)o;
                assert(e.op == TOKdsymbol);
                DsymbolExp se = cast(DsymbolExp)e;
                se.s.setFieldOffset(ad, poffset, isunion);
            }
            return;
        }

        if (!isField())
            return;
        assert(!(storage_class & (STCstatic | STCextern | STCparameter | STCtls)));

        //printf("+VarDeclaration::setFieldOffset(ad = %s) %s\n", ad.toChars(), toChars());

        /* Fields that are tuples appear both as part of TupleDeclarations and
         * as members. That means ignore them if they are already a field.
         */
        if (offset)
        {
            // already a field
            *poffset = ad.structsize; // Bugzilla 13613
            return;
        }
        for (size_t i = 0; i < ad.fields.dim; i++)
        {
            if (ad.fields[i] == this)
            {
                // already a field
                *poffset = ad.structsize; // Bugzilla 13613
                return;
            }
        }

        // Check for forward referenced types which will fail the size() call
        Type t = type.toBasetype();
        if (storage_class & STCref)
        {
            // References are the size of a pointer
            t = Type.tvoidptr;
        }
        Type tv = t.baseElemOf();
        if (tv.ty == Tstruct)
        {
            auto ts = cast(TypeStruct)tv;
            assert(ts.sym != ad);   // already checked in ad.determineFields()
            if (!ts.sym.determineSize(loc))
            {
                type = Type.terror;
                errors = true;
                return;
            }
        }

        // List in ad.fields. Even if the type is error, it's necessary to avoid
        // pointless error diagnostic "more initializers than fields" on struct literal.
        ad.fields.push(this);

        if (t.ty == Terror)
            return;

        const sz = t.size(loc);
        assert(sz != SIZE_INVALID && sz < uint.max);
        uint memsize = cast(uint)sz;                // size of member
        uint memalignsize = Target.fieldalign(t);   // size of member for alignment purposes
        offset = AggregateDeclaration.placeField(
            poffset,
            memsize, memalignsize, alignment,
            &ad.structsize, &ad.alignsize,
            isunion);

        //printf("\t%s: memalignsize = %d\n", toChars(), memalignsize);
        //printf(" addField '%s' to '%s' at offset %d, size = %d\n", toChars(), ad.toChars(), offset, memsize);
    }

    override final void semantic2(Scope* sc)
    {
        if (semanticRun < PASSsemanticdone && inuse)
            return;

        //printf("VarDeclaration::semantic2('%s')\n", toChars());

        if (_init && !toParent().isFuncDeclaration())
        {
            inuse++;
            version (none)
            {
                ExpInitializer ei = _init.isExpInitializer();
                if (ei)
                {
                    ei.exp.print();
                    printf("type = %p\n", ei.exp.type);
                }
            }
            // Bugzilla 14166: Don't run CTFE for the temporary variables inside typeof
            _init = _init.semantic(sc, type, sc.intypeof == 1 ? INITnointerpret : INITinterpret);
            inuse--;
        }
        if (_init && storage_class & STCmanifest)
        {
            /* Cannot initializer enums with CTFE classreferences and addresses of struct literals.
             * Scan initializer looking for them. Issue error if found.
             */
            if (ExpInitializer ei = _init.isExpInitializer())
            {
                static bool hasInvalidEnumInitializer(Expression e)
                {
                    static bool arrayHasInvalidEnumInitializer(Expressions* elems)
                    {
                        foreach (e; *elems)
                        {
                            if (e && hasInvalidEnumInitializer(e))
                                return true;
                        }
                        return false;
                    }

                    if (e.op == TOKclassreference)
                        return true;
                    if (e.op == TOKaddress && (cast(AddrExp)e).e1.op == TOKstructliteral)
                        return true;
                    if (e.op == TOKarrayliteral)
                        return arrayHasInvalidEnumInitializer((cast(ArrayLiteralExp)e).elements);
                    if (e.op == TOKstructliteral)
                        return arrayHasInvalidEnumInitializer((cast(StructLiteralExp)e).elements);
                    if (e.op == TOKassocarrayliteral)
                    {
                        AssocArrayLiteralExp ae = cast(AssocArrayLiteralExp)e;
                        return arrayHasInvalidEnumInitializer(ae.values) ||
                               arrayHasInvalidEnumInitializer(ae.keys);
                    }
                    return false;
                }

                if (hasInvalidEnumInitializer(ei.exp))
                    error(": Unable to initialize enum with class or pointer to struct. Use static const variable instead.");
            }
        }
        else if (_init && isThreadlocal())
        {
            if ((type.ty == Tclass) && type.isMutable() && !type.isShared())
            {
                ExpInitializer ei = _init.isExpInitializer();
                if (ei && ei.exp.op == TOKclassreference)
                    error("is mutable. Only const or immutable class thread local variable are allowed, not %s", type.toChars());
            }
            else if (type.ty == Tpointer && type.nextOf().ty == Tstruct && type.nextOf().isMutable() && !type.nextOf().isShared())
            {
                ExpInitializer ei = _init.isExpInitializer();
                if (ei && ei.exp.op == TOKaddress && (cast(AddrExp)ei.exp).e1.op == TOKstructliteral)
                {
                    error("is a pointer to mutable struct. Only pointers to const, immutable or shared struct thread local variable are allowed, not %s", type.toChars());
                }
            }
        }
        semanticRun = PASSsemantic2done;
    }

    override const(char)* kind() const
    {
        return "variable";
    }

    override final AggregateDeclaration isThis()
    {
        AggregateDeclaration ad = null;
        if (!(storage_class & (STCstatic | STCextern | STCmanifest | STCtemplateparameter | STCtls | STCgshared | STCctfe)))
        {
            for (Dsymbol s = this; s; s = s.parent)
            {
                ad = s.isMember();
                if (ad)
                    break;
                if (!s.parent || !s.parent.isTemplateMixin())
                    break;
            }
        }
        return ad;
    }

    override final bool needThis()
    {
        //printf("VarDeclaration::needThis(%s, x%x)\n", toChars(), storage_class);
        return isField();
    }

    override final bool isExport()
    {
        return protection.kind == PROTexport;
    }

    override final bool isImportedSymbol()
    {
        if (protection.kind == PROTexport && !_init && (storage_class & STCstatic || parent.isModule()))
            return true;
        return false;
    }

    /*******************************
     * Does symbol go into data segment?
     * Includes extern variables.
     */
    override final bool isDataseg()
    {
        version (none)
        {
            printf("VarDeclaration::isDataseg(%p, '%s')\n", this, toChars());
            printf("%llx, isModule: %p, isTemplateInstance: %p\n", storage_class & (STCstatic | STCconst), parent.isModule(), parent.isTemplateInstance());
            printf("parent = '%s'\n", parent.toChars());
        }

        if (isdataseg == 0) // the value is not cached
        {
            isdataseg = 2; // The Variables does not go into the datasegment

            if (!canTakeAddressOf())
            {
                return false;
            }

            Dsymbol parent = toParent();
            if (!parent && !(storage_class & STCstatic))
            {
                error("forward referenced");
                type = Type.terror;
            }
            else if (storage_class & (STCstatic | STCextern | STCtls | STCgshared) ||
                parent.isModule() || parent.isTemplateInstance())
            {
                isdataseg = 1; // It is in the DataSegment
            }
        }

        return (isdataseg == 1);
    }
    /************************************
     * Does symbol go into thread local storage?
     */
    override final bool isThreadlocal()
    {
        //printf("VarDeclaration::isThreadlocal(%p, '%s')\n", this, toChars());
        /* Data defaults to being thread-local. It is not thread-local
         * if it is immutable, const or shared.
         */
        bool i = isDataseg() && !(storage_class & (STCimmutable | STCconst | STCshared | STCgshared));
        //printf("\treturn %d\n", i);
        return i;
    }

    /********************************************
     * Can variable be read and written by CTFE?
     */
    final bool isCTFE()
    {
        return (storage_class & STCctfe) != 0; // || !isDataseg();
    }

    final bool isOverlappedWith(VarDeclaration v)
    {
        const vsz = v.type.size();
        const tsz = type.size();
        assert(vsz != SIZE_INVALID && tsz != SIZE_INVALID);
        return    offset < v.offset + vsz &&
                v.offset <   offset + tsz;
    }

    override final bool hasPointers()
    {
        //printf("VarDeclaration::hasPointers() %s, ty = %d\n", toChars(), type->ty);
        return (!isDataseg() && type.hasPointers());
    }

    /*************************************
     * Return true if we can take the address of this variable.
     */
    final bool canTakeAddressOf()
    {
        return !(storage_class & STCmanifest);
    }

    /******************************************
     * Return true if variable needs to call the destructor.
     */
    final bool needsScopeDtor()
    {
        //printf("VarDeclaration::needsScopeDtor() %s\n", toChars());
        return edtor && !(storage_class & STCnodtor);
    }

    /******************************************
     * If a variable has a scope destructor call, return call for it.
     * Otherwise, return NULL.
     */
    final Expression callScopeDtor(Scope* sc)
    {
        //printf("VarDeclaration::callScopeDtor() %s\n", toChars());

        // Destruction of STCfield's is handled by buildDtor()
        if (storage_class & (STCnodtor | STCref | STCout | STCfield))
        {
            return null;
        }

        Expression e = null;
        // Destructors for structs and arrays of structs
        Type tv = type.baseElemOf();
        if (tv.ty == Tstruct)
        {
            StructDeclaration sd = (cast(TypeStruct)tv).sym;
            if (!sd.dtor)
                return null;

            const sz = type.size();
            assert(sz != SIZE_INVALID);
            if (!sz)
                return null;

            if (type.toBasetype().ty == Tstruct)
            {
                // v.__xdtor()
                e = new VarExp(loc, this);

                /* This is a hack so we can call destructors on const/immutable objects.
                 * Need to add things like "const ~this()" and "immutable ~this()" to
                 * fix properly.
                 */
                e.type = e.type.mutableOf();

                e = new DotVarExp(loc, e, sd.dtor, false);
                e = new CallExp(loc, e);
            }
            else
            {
                // _ArrayDtor(v[0 .. n])
                e = new VarExp(loc, this);

                const sdsz = sd.type.size();
                assert(sdsz != SIZE_INVALID && sdsz != 0);
                const n = sz / sdsz;
                e = new SliceExp(loc, e, new IntegerExp(loc, 0, Type.tsize_t), new IntegerExp(loc, n, Type.tsize_t));

                // Prevent redundant bounds check
                (cast(SliceExp)e).upperIsInBounds = true;
                (cast(SliceExp)e).lowerIsLessThanUpper = true;

                // This is a hack so we can call destructors on const/immutable objects.
                e.type = sd.type.arrayOf();

                e = new CallExp(loc, new IdentifierExp(loc, Id._ArrayDtor), e);
            }
            return e;
        }
        // Destructors for classes
        if (storage_class & (STCauto | STCscope) && !(storage_class & STCparameter))
        {
            for (ClassDeclaration cd = type.isClassHandle(); cd; cd = cd.baseClass)
            {
                /* We can do better if there's a way with onstack
                 * classes to determine if there's no way the monitor
                 * could be set.
                 */
                //if (cd->isInterfaceDeclaration())
                //    error("interface %s cannot be scope", cd->toChars());

                if (cd.cpp)
                {
                    // Destructors are not supported on extern(C++) classes
                    break;
                }
                if (mynew || onstack || cd.dtors.dim) // if any destructors
                {
                    // delete this;
                    Expression ec;
                    ec = new VarExp(loc, this);
                    e = new DeleteExp(loc, ec);
                    e.type = Type.tvoid;
                    break;
                }
            }
        }
        return e;
    }

    /*******************************************
     * If variable has a constant expression initializer, get it.
     * Otherwise, return null.
     */
    final Expression getConstInitializer(bool needFullType = true)
    {
        assert(type && _init);

        // Ungag errors when not speculative
        uint oldgag = global.gag;
        if (global.gag)
        {
            Dsymbol sym = toParent().isAggregateDeclaration();
            if (sym && !sym.isSpeculative())
                global.gag = 0;
        }

        if (_scope)
        {
            inuse++;
            _init = _init.semantic(_scope, type, INITinterpret);
            _scope = null;
            inuse--;
        }

        Expression e = _init.toExpression(needFullType ? type : null);
        global.gag = oldgag;
        return e;
    }

    /*******************************************
     * Helper function for the expansion of manifest constant.
     */
    final Expression expandInitializer(Loc loc)
    {
        assert((storage_class & STCmanifest) && _init);

        auto e = getConstInitializer();
        if (!e)
        {
            .error(loc, "cannot make expression out of initializer for %s", toChars());
            return new ErrorExp();
        }

        e = e.copy();
        e.loc = loc;    // for better error message
        return e;
    }

    override final void checkCtorConstInit()
    {
        version (none)
        {
            /* doesn't work if more than one static ctor */
            if (ctorinit == 0 && isCtorinit() && !isField())
                error("missing initializer in static constructor for const variable");
        }
    }

    /************************************
     * Check to see if this variable is actually in an enclosing function
     * rather than the current one.
     * Returns true if error occurs.
     */
    final bool checkNestedReference(Scope* sc, Loc loc)
    {
        //printf("VarDeclaration::checkNestedReference() %s\n", toChars());
        if (sc.intypeof == 1 || (sc.flags & SCOPEctfe))
            return false;
        if (!parent || parent == sc.parent)
            return false;
        if (isDataseg() || (storage_class & STCmanifest))
            return false;

        // The current function
        FuncDeclaration fdthis = sc.parent.isFuncDeclaration();
        if (!fdthis)
            return false; // out of function scope

        Dsymbol p = toParent2();

        // Function literals from fdthis to p must be delegates
        checkNestedRef(fdthis, p);

        // The function that this variable is in
        FuncDeclaration fdv = p.isFuncDeclaration();
        if (!fdv || fdv == fdthis)
            return false;

        // Add fdthis to nestedrefs[] if not already there
        for (size_t i = 0; 1; i++)
        {
            if (i == nestedrefs.dim)
            {
                nestedrefs.push(fdthis);
                break;
            }
            if (nestedrefs[i] == fdthis)
                break;
        }

        /* __require and __ensure will always get called directly,
         * so they never make outer functions closure.
         */
        if (fdthis.ident == Id.require || fdthis.ident == Id.ensure)
            return false;

        //printf("\tfdv = %s\n", fdv.toChars());
        //printf("\tfdthis = %s\n", fdthis.toChars());
        if (loc.filename)
        {
            int lv = fdthis.getLevel(loc, sc, fdv);
            if (lv == -2) // error
                return true;
        }

        // Add this to fdv.closureVars[] if not already there
        for (size_t i = 0; 1; i++)
        {
            if (i == fdv.closureVars.dim)
            {
                if (!sc.intypeof && !(sc.flags & SCOPEcompile))
                    fdv.closureVars.push(this);
                break;
            }
            if (fdv.closureVars[i] == this)
                break;
        }

        //printf("fdthis is %s\n", fdthis.toChars());
        //printf("var %s in function %s is nested ref\n", toChars(), fdv.toChars());
        // __dollar creates problems because it isn't a real variable Bugzilla 3326
        if (ident == Id.dollar)
        {
            .error(loc, "cannnot use $ inside a function literal");
            return true;
        }
        if (ident == Id.withSym) // Bugzilla 1759
        {
            ExpInitializer ez = _init.isExpInitializer();
            assert(ez);
            Expression e = ez.exp;
            if (e.op == TOKconstruct || e.op == TOKblit)
                e = (cast(AssignExp)e).e2;
            return lambdaCheckForNestedRef(e, sc);
        }

        return false;
    }

    override final Dsymbol toAlias()
    {
        //printf("VarDeclaration::toAlias('%s', this = %p, aliassym = %p)\n", toChars(), this, aliassym);
        if ((!type || !type.deco) && _scope)
            semantic(_scope);

        assert(this != aliassym);
        Dsymbol s = aliassym ? aliassym.toAlias() : this;
        return s;
    }

    // Eliminate need for dynamic_cast
    override final inout(VarDeclaration) isVarDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * This is a shell around a back end symbol
 */
extern (C++) final class SymbolDeclaration : Declaration
{
    StructDeclaration dsym;

    extern (D) this(Loc loc, StructDeclaration dsym)
    {
        super(dsym.ident);
        this.loc = loc;
        this.dsym = dsym;
        storage_class |= STCconst;
    }

    // Eliminate need for dynamic_cast
    override inout(SymbolDeclaration) isSymbolDeclaration() inout
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
extern (C++) class TypeInfoDeclaration : VarDeclaration
{
    Type tinfo;

    final extern (D) this(Type tinfo)
    {
        super(Loc(), Type.dtypeinfo.type, tinfo.getTypeInfoIdent(), null);
        this.tinfo = tinfo;
        storage_class = STCstatic | STCgshared;
        protection = Prot(PROTpublic);
        linkage = LINKc;
    }

    static TypeInfoDeclaration create(Type tinfo)
    {
        return new TypeInfoDeclaration(tinfo);
    }

    override final Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(0); // should never be produced by syntax
    }

    override final void semantic(Scope* sc)
    {
        assert(linkage == LINKc);
    }

    override final const(char)* toChars()
    {
        //printf("TypeInfoDeclaration::toChars() tinfo = %s\n", tinfo->toChars());
        OutBuffer buf;
        buf.writestring("typeid(");
        buf.writestring(tinfo.toChars());
        buf.writeByte(')');
        return buf.extractString();
    }

    override final inout(TypeInfoDeclaration) isTypeInfoDeclaration() inout
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
extern (C++) final class TypeInfoStructDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfostruct)
        {
            ObjectNotFound(Id.TypeInfo_Struct);
        }
        type = Type.typeinfostruct.type;
    }

    static TypeInfoStructDeclaration create(Type tinfo)
    {
        return new TypeInfoStructDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoClassDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoclass)
        {
            ObjectNotFound(Id.TypeInfo_Class);
        }
        type = Type.typeinfoclass.type;
    }

    static TypeInfoClassDeclaration create(Type tinfo)
    {
        return new TypeInfoClassDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoInterfaceDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfointerface)
        {
            ObjectNotFound(Id.TypeInfo_Interface);
        }
        type = Type.typeinfointerface.type;
    }

    static TypeInfoInterfaceDeclaration create(Type tinfo)
    {
        return new TypeInfoInterfaceDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoPointerDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfopointer)
        {
            ObjectNotFound(Id.TypeInfo_Pointer);
        }
        type = Type.typeinfopointer.type;
    }

    static TypeInfoPointerDeclaration create(Type tinfo)
    {
        return new TypeInfoPointerDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoArrayDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoarray)
        {
            ObjectNotFound(Id.TypeInfo_Array);
        }
        type = Type.typeinfoarray.type;
    }

    static TypeInfoArrayDeclaration create(Type tinfo)
    {
        return new TypeInfoArrayDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoStaticArrayDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfostaticarray)
        {
            ObjectNotFound(Id.TypeInfo_StaticArray);
        }
        type = Type.typeinfostaticarray.type;
    }

    static TypeInfoStaticArrayDeclaration create(Type tinfo)
    {
        return new TypeInfoStaticArrayDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoAssociativeArrayDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoassociativearray)
        {
            ObjectNotFound(Id.TypeInfo_AssociativeArray);
        }
        type = Type.typeinfoassociativearray.type;
    }

    static TypeInfoAssociativeArrayDeclaration create(Type tinfo)
    {
        return new TypeInfoAssociativeArrayDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoEnumDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoenum)
        {
            ObjectNotFound(Id.TypeInfo_Enum);
        }
        type = Type.typeinfoenum.type;
    }

    static TypeInfoEnumDeclaration create(Type tinfo)
    {
        return new TypeInfoEnumDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoFunctionDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfofunction)
        {
            ObjectNotFound(Id.TypeInfo_Function);
        }
        type = Type.typeinfofunction.type;
    }

    static TypeInfoFunctionDeclaration create(Type tinfo)
    {
        return new TypeInfoFunctionDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoDelegateDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfodelegate)
        {
            ObjectNotFound(Id.TypeInfo_Delegate);
        }
        type = Type.typeinfodelegate.type;
    }

    static TypeInfoDelegateDeclaration create(Type tinfo)
    {
        return new TypeInfoDelegateDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoTupleDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfotypelist)
        {
            ObjectNotFound(Id.TypeInfo_Tuple);
        }
        type = Type.typeinfotypelist.type;
    }

    static TypeInfoTupleDeclaration create(Type tinfo)
    {
        return new TypeInfoTupleDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoConstDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoconst)
        {
            ObjectNotFound(Id.TypeInfo_Const);
        }
        type = Type.typeinfoconst.type;
    }

    static TypeInfoConstDeclaration create(Type tinfo)
    {
        return new TypeInfoConstDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoInvariantDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoinvariant)
        {
            ObjectNotFound(Id.TypeInfo_Invariant);
        }
        type = Type.typeinfoinvariant.type;
    }

    static TypeInfoInvariantDeclaration create(Type tinfo)
    {
        return new TypeInfoInvariantDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoSharedDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfoshared)
        {
            ObjectNotFound(Id.TypeInfo_Shared);
        }
        type = Type.typeinfoshared.type;
    }

    static TypeInfoSharedDeclaration create(Type tinfo)
    {
        return new TypeInfoSharedDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoWildDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfowild)
        {
            ObjectNotFound(Id.TypeInfo_Wild);
        }
        type = Type.typeinfowild.type;
    }

    static TypeInfoWildDeclaration create(Type tinfo)
    {
        return new TypeInfoWildDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 */
extern (C++) final class TypeInfoVectorDeclaration : TypeInfoDeclaration
{
    extern (D) this(Type tinfo)
    {
        super(tinfo);
        if (!Type.typeinfovector)
        {
            ObjectNotFound(Id.TypeInfo_Vector);
        }
        type = Type.typeinfovector.type;
    }

    static TypeInfoVectorDeclaration create(Type tinfo)
    {
        return new TypeInfoVectorDeclaration(tinfo);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * For the "this" parameter to member functions
 */
extern (C++) final class ThisDeclaration : VarDeclaration
{
    extern (D) this(Loc loc, Type t)
    {
        super(loc, t, Id.This, null);
        storage_class |= STCnodtor;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(0); // should never be produced by syntax
    }

    override inout(ThisDeclaration) isThisDeclaration() inout
    {
        return this;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}
