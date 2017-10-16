/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (c) 1999-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/ddmd/declaration.d, _declaration.d)
 */

module ddmd.declaration;

// Online documentation: https://dlang.org/phobos/ddmd_declaration.html

import ddmd.aggregate;
import ddmd.arraytypes;
import ddmd.dclass;
import ddmd.delegatize;
import ddmd.dscope;
import ddmd.dstruct;
import ddmd.dsymbol;
import ddmd.dsymbolsem;
import ddmd.dtemplate;
import ddmd.errors;
import ddmd.expression;
import ddmd.func;
import ddmd.globals;
import ddmd.id;
import ddmd.identifier;
import ddmd.init;
import ddmd.initsem;
import ddmd.intrange;
import ddmd.mtype;
import ddmd.root.outbuffer;
import ddmd.root.rootobject;
import ddmd.semantic;
import ddmd.target;
import ddmd.tokens;
import ddmd.typesem;
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
        if (!ensureStaticLinkTo(s, sparent))
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
enum STCvariadic            = (1L << 16);   // the 'variadic' parameter in: T foo(T a, U b, V variadic...)
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
enum STCreturn              = (1L << 44);   // 'return ref' or 'return scope' for function parameters
enum STCautoref             = (1L << 45);   // Mark for the already deduced 'auto ref' parameter
enum STCinference           = (1L << 46);   // do attribute inference
enum STCexptemp             = (1L << 47);   // temporary variable that has lifetime restricted to an expression
enum STCmaybescope          = (1L << 48);   // parameter might be 'scope'
enum STCscopeinferred       = (1L << 49);   // 'scope' has been inferred and should not be part of mangling
enum STCfuture              = (1L << 50);   // introducing new base class function
enum STClocal               = (1L << 51);   // do not forward (see ddmd.dsymbol.ForwardingScopeDsymbol).

enum STC_TYPECTOR = (STCconst | STCimmutable | STCshared | STCwild);
enum STC_FUNCATTR = (STCref | STCnothrow | STCnogc | STCpure | STCproperty | STCsafe | STCtrusted | STCsystem);

extern (C++) __gshared const(StorageClass) STCStorageClass =
    (STCauto | STCscope | STCstatic | STCextern | STCconst | STCfinal | STCabstract | STCsynchronized |
     STCdeprecated | STCfuture | STCoverride | STClazy | STCalias | STCout | STCin | STCmanifest |
     STCimmutable | STCshared | STCwild | STCnothrow | STCnogc | STCpure | STCref | STCtls | STCgshared |
     STCproperty | STCsafe | STCtrusted | STCsystem | STCdisable | STClocal);

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

    bool isAbstract()
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

    final bool isFuture()
    {
        return (storage_class & STCfuture) != 0;
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
                if (o.dyncast() != DYNCAST.type)
                {
                    //printf("\tnot[%d], %p, %d\n", i, o, o.dyncast());
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
                //printf("type = %s\n", t.toChars());
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
                return tupletype.typeSemantic(Loc(), null);
        }
        return tupletype;
    }

    override Dsymbol toAlias2()
    {
        //printf("TupleDeclaration::toAlias2() '%s' objects = %s\n", toChars(), objects.toChars());
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
            if (o.dyncast() == DYNCAST.expression)
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
        //printf("AliasDeclaration(id = '%s', type = %p)\n", id.toChars(), type);
        //printf("type = '%s'\n", type.toChars());
        this.loc = loc;
        this.type = type;
        assert(type);
    }

    extern (D) this(Loc loc, Identifier id, Dsymbol s)
    {
        super(id);
        //printf("AliasDeclaration(id = '%s', s = %p)\n", id.toChars(), s);
        assert(s != this);
        this.loc = loc;
        this.aliassym = s;
        assert(s);
    }

    static AliasDeclaration create(Loc loc, Identifier id, Type type)
    {
        return new AliasDeclaration(loc, id, type);
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("AliasDeclaration::syntaxCopy()\n");
        assert(!s);
        AliasDeclaration sa = type ? new AliasDeclaration(loc, ident, type.syntaxCopy()) : new AliasDeclaration(loc, ident, aliassym.syntaxCopy(null));
        sa.storage_class = storage_class;
        return sa;
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
            //printf("[%s] type = %s, s = %p, this = %p\n", loc.toChars(), type.toChars(), s, this);
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
                Type t = type.typeSemantic(loc, _scope);
                if (t.ty == Terror)
                    goto Lerr;
                if (global.errors != olderrors)
                    goto Lerr;
                //printf("t = %s\n", t.toChars());
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
                aliasSemantic(this, _scope);
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
        //printf("OverDeclaration::overloadInsert('%s') aliassym = %p, overnext = %p\n", s.toChars(), aliassym, overnext);
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
    uint sequenceNumber;            // order the variables are declared
    __gshared uint nextSequenceNumber;   // the counter for sequenceNumber
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
    bool doNotInferScope;           // do not infer 'scope' for this variable
    ubyte isdataseg;                // private data for isDataseg 0 unset, 1 true, 2 false
    Dsymbol aliassym;               // if redone as alias to another symbol
    VarDeclaration lastVar;         // Linked list of variables for goto-skips-init detection
    uint endlinnum;                 // line number of end of scope that this var lives in

    // When interpreting, these point to the value (NULL if value not determinable)
    // The index of this variable on the CTFE stack, -1 if not allocated
    int ctfeAdrOnStack;

    Expression edtor;               // if !=null, does the destruction of the variable
    IntRange* range;                // if !=null, the variable is known to be within the range

    final extern (D) this(Loc loc, Type type, Identifier id, Initializer _init, StorageClass storage_class = STCundefined)
    {
        super(id);
        //printf("VarDeclaration('%s')\n", id.toChars());
        assert(id);
        debug
        {
            if (!type && !_init)
            {
                //printf("VarDeclaration('%s')\n", id.toChars());
                //*(char*)0=0;
            }
        }

        assert(type || _init);
        this.type = type;
        this._init = _init;
        this.loc = loc;
        ctfeAdrOnStack = -1;
        this.storage_class = storage_class;
        sequenceNumber = ++nextSequenceNumber;
    }

    override Dsymbol syntaxCopy(Dsymbol s)
    {
        //printf("VarDeclaration::syntaxCopy(%s)\n", toChars());
        assert(!s);
        auto v = new VarDeclaration(loc, type ? type.syntaxCopy() : null, ident, _init ? _init.syntaxCopy() : null, storage_class);
        return v;
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
                assert(o.dyncast() == DYNCAST.expression);
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
            *poffset = ad.structsize; // https://issues.dlang.org/show_bug.cgi?id=13613
            return;
        }
        for (size_t i = 0; i < ad.fields.dim; i++)
        {
            if (ad.fields[i] == this)
            {
                // already a field
                *poffset = ad.structsize; // https://issues.dlang.org/show_bug.cgi?id=13613
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
            printf("%llx, isModule: %p, isTemplateInstance: %p, isNspace: %p\n",
                   storage_class & (STCstatic | STCconst), parent.isModule(), parent.isTemplateInstance(), parent.isNspace());
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
                parent.isModule() || parent.isTemplateInstance() || parent.isNspace())
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
        //printf("VarDeclaration::hasPointers() %s, ty = %d\n", toChars(), type.ty);
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
            if (!sd.dtor || sd.errors)
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

                // Enable calling destructors on shared objects.
                // The destructor is always a single, non-overloaded function,
                // and must serve both shared and non-shared objects.
                e.type = e.type.unSharedOf;

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
                //if (cd.isInterfaceDeclaration())
                //    error("interface %s cannot be scope", cd.toChars());

                // Destroying C++ scope classes crashes currently. Since C++ class dtors are not currently supported, simply do not run dtors for them.
                // See https://issues.dlang.org/show_bug.cgi?id=13182
                if (cd.cpp)
                {
                    break;
                }
                if (mynew || onstack) // if any destructors
                {
                    // delete this;
                    Expression ec;
                    ec = new VarExp(loc, this);
                    e = new DeleteExp(loc, ec, true);
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

        Expression e = _init.initializerToExpression(needFullType ? type : null);
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
        ensureStaticLinkTo(fdthis, p);

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
        // __dollar creates problems because it isn't a real variable
        // https://issues.dlang.org/show_bug.cgi?id=3326
        if (ident == Id.dollar)
        {
            .error(loc, "cannnot use $ inside a function literal");
            return true;
        }
        if (ident == Id.withSym) // https://issues.dlang.org/show_bug.cgi?id=1759
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
            semantic(this, _scope);

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

    /**********************************
     * Determine if `this` has a lifetime that lasts past
     * the destruction of `v`
     * Params:
     *  v = variable to test against
     * Returns:
     *  true if it does
     */
    final bool enclosesLifetimeOf(VarDeclaration v) const pure
    {
        return sequenceNumber < v.sequenceNumber;
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
        alignment = Target.ptrsize;
    }

    static TypeInfoDeclaration create(Type tinfo)
    {
        return new TypeInfoDeclaration(tinfo);
    }

    override final Dsymbol syntaxCopy(Dsymbol s)
    {
        assert(0); // should never be produced by syntax
    }

    override final const(char)* toChars()
    {
        //printf("TypeInfoDeclaration::toChars() tinfo = %s\n", tinfo.toChars());
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
