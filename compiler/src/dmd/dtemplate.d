/**
 * Defines `TemplateDeclaration`, `TemplateInstance` and a few utilities
 *
 * This modules holds the two main template types:
 * `TemplateDeclaration`, which is the user-provided declaration of a template,
 * and `TemplateInstance`, which is an instance of a `TemplateDeclaration`
 * with specific arguments.
 *
 * Template_Parameter:
 * Additionally, the classes for template parameters are defined in this module.
 * The base class, `TemplateParameter`, is inherited by:
 * - `TemplateTypeParameter`
 * - `TemplateThisParameter`
 * - `TemplateValueParameter`
 * - `TemplateAliasParameter`
 * - `TemplateTupleParameter`
 *
 * Templates_semantic:
 * The start of the template instantiation process looks like this:
 * - A `TypeInstance` or `TypeIdentifier` is encountered.
 *   `TypeInstance` have a bang (e.g. `Foo!(arg)`) while `TypeIdentifier` don't.
 * - A `TemplateInstance` is instantiated
 * - Semantic is run on the `TemplateInstance` (see `dmd.dsymbolsem`)
 * - The `TemplateInstance` search for its `TemplateDeclaration`,
 *   runs semantic on the template arguments and deduce the best match
 *   among the possible overloads.
 * - The `TemplateInstance` search for existing instances with the same
 *   arguments, and uses it if found.
 * - Otherwise, the rest of semantic is run on the `TemplateInstance`.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/dtemplate.d, _dtemplate.d)
 * Documentation:  https://dlang.org/phobos/dmd_dtemplate.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/dtemplate.d
 */

module dmd.dtemplate;

import core.stdc.stdio;
import core.stdc.string;
import dmd.aggregate;
import dmd.aliasthis;
import dmd.arraytypes;
import dmd.astenums;
import dmd.ast_node;
import dmd.attrib;
import dmd.dcast;
import dmd.dclass;
import dmd.declaration;
import dmd.dinterpret;
import dmd.dmodule;
import dmd.dscope;
import dmd.dsymbol;
import dmd.dsymbolsem : dsymbolSemantic, aliasSemantic, search, oneMembers;
import dmd.errors;
import dmd.errorsink;
import dmd.expression;
import dmd.expressionsem : resolveLoc, expressionSemantic, resolveProperties, checkValue;
import dmd.func;
import dmd.funcsem : functionSemantic, overloadApply;
import dmd.globals;
import dmd.hdrgen;
import dmd.id;
import dmd.identifier;
import dmd.impcnvtab;
import dmd.init;
import dmd.location;
import dmd.mangle;
import dmd.mtype;
import dmd.opover;
import dmd.optimize;
import dmd.root.array;
import dmd.common.outbuffer;
import dmd.rootobject;
import dmd.templatesem : matchWithInstance, formatParamsWithTiargs, leastAsSpecialized,
                         declareParameter, deduceType, deduceTypeHelper, emptyArrayElement, getExpression;
import dmd.tokens;
import dmd.typesem : hasPointers, typeSemantic, merge, merge2, resolve, toDsymbol,
                     addStorageClass, isBaseOf, equivalent, sarrayOf, constOf, mutableOf, unSharedOf,
                     unqualify, aliasthisOf, castMod, substWildTo, addMod, resolveNamedArgs;
import dmd.visitor;

import dmd.templateparamsem;

//debug = FindExistingInstance; // print debug stats of findExistingInstance
private enum LOG = false;

enum IDX_NOTFOUND = 0x12345678;

pure nothrow @nogc @trusted
{

/********************************************
 * These functions substitute for dynamic_cast. dynamic_cast does not work
 * on earlier versions of gcc.
 */
inout(Expression) isExpression(inout RootObject o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o.dyncast() != DYNCAST.expression)
        return null;
    return cast(inout(Expression))o;
}

inout(Dsymbol) isDsymbol(inout RootObject o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o.dyncast() != DYNCAST.dsymbol)
        return null;
    return cast(inout(Dsymbol))o;
}

inout(Type) isType(inout RootObject o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o.dyncast() != DYNCAST.type)
        return null;
    return cast(inout(Type))o;
}

inout(Tuple) isTuple(inout RootObject o)
{
    //return dynamic_cast<Tuple *>(o);
    if (!o || o.dyncast() != DYNCAST.tuple)
        return null;
    return cast(inout(Tuple))o;
}

inout(Parameter) isParameter(inout RootObject o)
{
    //return dynamic_cast<Parameter *>(o);
    if (!o || o.dyncast() != DYNCAST.parameter)
        return null;
    return cast(inout(Parameter))o;
}

inout(Identifier) isIdentifier(inout RootObject o)
{
    if (!o || o.dyncast() != DYNCAST.identifier)
        return null;
    return cast(inout(Identifier))o;
}

inout(TemplateParameter) isTemplateParameter(inout RootObject o)
{
    if (!o || o.dyncast() != DYNCAST.templateparameter)
        return null;
    return cast(inout(TemplateParameter))o;
}

} // end @trusted casts

pure nothrow @nogc @safe
{

/**************************************
 * Is this Object an error?
 */
bool isError(const RootObject o)
{
    if (const t = isType(o))
        return (t.ty == Terror);
    if (const e = isExpression(o))
        return (e.op == EXP.error || !e.type || e.type.ty == Terror);
    if (const v = isTuple(o))
        return arrayObjectIsError(v.objects);
    const s = isDsymbol(o);
    assert(s);
    if (s.errors)
        return true;
    return s.parent ? isError(s.parent) : false;
}

/**************************************
 * Are any of the Objects an error?
 */
bool arrayObjectIsError(const ref Objects args)
{
    foreach (const o; args)
    {
        if (isError(o))
            return true;
    }
    return false;
}

/***********************
 * Try to get arg as a type.
 */
inout(Type) getType(inout RootObject o)
{
    inout t = isType(o);
    if (!t)
    {
        if (inout e = isExpression(o))
            return e.type;
    }
    return t;
}

}

/***********************************
 * If oarg represents a Dsymbol, return that Dsymbol
 * Params:
 *      oarg = argument to check
 * Returns:
 *      Dsymbol if a symbol, null if not
 */
Dsymbol getDsymbol(RootObject oarg)
{
    //printf("getDsymbol()\n");
    //printf("e %p s %p t %p v %p\n", isExpression(oarg), isDsymbol(oarg), isType(oarg), isTuple(oarg));
    if (auto ea = isExpression(oarg))
    {
        // Try to convert Expression to symbol
        if (auto ve = ea.isVarExp())
            return ve.var;
        if (auto fe = ea.isFuncExp())
            return fe.td ? fe.td : fe.fd;
        if (auto te = ea.isTemplateExp())
            return te.td;
        if (auto te = ea.isScopeExp())
            return te.sds;
        return null;
    }
    // Try to convert Type to symbol
    if (auto ta = isType(oarg))
        return ta.toDsymbol(null);
    return isDsymbol(oarg); // if already a symbol
}

/******************************
 * See if two objects match
 * Params:
 *      o1 = first object
 *      o2 = second object
 * Returns: true if they match
 */
bool match(RootObject o1, RootObject o2)
{
    enum log = false;

    static if (log)
    {
        printf("match() o1 = %p %s (%d), o2 = %p %s (%d)\n",
            o1, o1.toChars(), o1.dyncast(), o2, o2.toChars(), o2.dyncast());
    }

    bool yes()
    {
        static if (log)
            printf("\t. match\n");
        return true;
    }
    bool no()
    {
        static if (log)
            printf("\t. nomatch\n");
        return false;
    }
    /* A proper implementation of the various equals() overrides
     * should make it possible to just do o1.equals(o2), but
     * we'll do that another day.
     */
    /* Manifest constants should be compared by their values,
     * at least in template arguments.
     */

    if (auto t1 = isType(o1))
    {
        auto t2 = isType(o2);
        if (!t2)
            return no();

        static if (log)
        {
            printf("\tt1 = %s\n", t1.toChars());
            printf("\tt2 = %s\n", t2.toChars());
        }
        if (!t1.equals(t2))
            return no();

        return yes();
    }
    if (auto e1 = getExpression(o1))
    {
        auto e2 = getExpression(o2);
        if (!e2)
            return no();

        static if (log)
        {
            printf("\te1 = %s '%s' %s\n", e1.type ? e1.type.toChars() : "null", EXPtoString(e1.op).ptr, e1.toChars());
            printf("\te2 = %s '%s' %s\n", e2.type ? e2.type.toChars() : "null", EXPtoString(e2.op).ptr, e2.toChars());
        }

        // two expressions can be equal although they do not have the same
        // type; that happens when they have the same value. So check type
        // as well as expression equality to ensure templates are properly
        // matched.
        if (!(e1.type && e2.type && e1.type.equals(e2.type)) || !e1.equals(e2))
            return no();

        return yes();
    }
    if (auto s1 = isDsymbol(o1))
    {
        auto s2 = isDsymbol(o2);
        if (!s2)
            return no();

        static if (log)
        {
            printf("\ts1 = %s \n", s1.kind(), s1.toChars());
            printf("\ts2 = %s \n", s2.kind(), s2.toChars());
        }
        if (!s1.equals(s2))
            return no();
        if (s1.parent != s2.parent && !s1.isFuncDeclaration() && !s2.isFuncDeclaration())
            return no();

        return yes();
    }
    if (auto u1 = isTuple(o1))
    {
        auto u2 = isTuple(o2);
        if (!u2)
            return no();

        static if (log)
        {
            printf("\tu1 = %s\n", u1.toChars());
            printf("\tu2 = %s\n", u2.toChars());
        }
        if (!arrayObjectMatch(u1.objects, u2.objects))
            return no();

        return yes();
    }
    return yes();
}

/************************************
 * Match an array of them.
 */
bool arrayObjectMatch(ref Objects oa1, ref Objects oa2)
{
    if (&oa1 == &oa2)
        return true;
    if (oa1.length != oa2.length)
        return false;
    immutable oa1dim = oa1.length;
    auto oa1d = oa1[].ptr;
    auto oa2d = oa2[].ptr;
    foreach (j; 0 .. oa1dim)
    {
        RootObject o1 = oa1d[j];
        RootObject o2 = oa2d[j];
        if (!match(o1, o2))
        {
            return false;
        }
    }
    return true;
}

/************************************
 * Return hash of Objects.
 */
private size_t arrayObjectHash(ref Objects oa1)
{
    import dmd.root.hash : mixHash;

    size_t hash = 0;
    foreach (o1; oa1)
    {
        /* Must follow the logic of match()
         */
        if (auto t1 = isType(o1))
            hash = mixHash(hash, cast(size_t)t1.deco);
        else if (auto e1 = getExpression(o1))
            hash = mixHash(hash, expressionHash(e1));
        else if (auto s1 = isDsymbol(o1))
        {
            if (auto fa1 = s1.isFuncAliasDeclaration())
                s1 = fa1.toAliasFunc();
            hash = mixHash(hash, mixHash(cast(size_t)cast(void*)s1.getIdent(), cast(size_t)cast(void*)s1.parent));
        }
        else if (auto u1 = isTuple(o1))
            hash = mixHash(hash, arrayObjectHash(u1.objects));
    }
    return hash;
}


/************************************
 * Computes hash of expression.
 * Handles all Expression classes and MUST match their equals method,
 * i.e. e1.equals(e2) implies expressionHash(e1) == expressionHash(e2).
 */
private size_t expressionHash(Expression e)
{
    import dmd.root.ctfloat : CTFloat;
    import dmd.root.hash : calcHash, mixHash;

    switch (e.op)
    {
    case EXP.int64:
        return cast(size_t) e.isIntegerExp().getInteger();

    case EXP.float64:
        return CTFloat.hash(e.isRealExp().value);

    case EXP.complex80:
        auto ce = e.isComplexExp();
        return mixHash(CTFloat.hash(ce.toReal), CTFloat.hash(ce.toImaginary));

    case EXP.identifier:
        return cast(size_t)cast(void*) e.isIdentifierExp().ident;

    case EXP.null_:
        return cast(size_t)cast(void*) e.isNullExp().type;

    case EXP.string_:
        return calcHash(e.isStringExp.peekData());

    case EXP.tuple:
    {
        auto te = e.isTupleExp();
        size_t hash = 0;
        hash += te.e0 ? expressionHash(te.e0) : 0;
        foreach (elem; *te.exps)
            hash = mixHash(hash, expressionHash(elem));
        return hash;
    }

    case EXP.arrayLiteral:
    {
        auto ae = e.isArrayLiteralExp();
        size_t hash;
        foreach (i; 0 .. ae.elements.length)
            hash = mixHash(hash, expressionHash(ae[i]));
        return hash;
    }

    case EXP.assocArrayLiteral:
    {
        auto ae = e.isAssocArrayLiteralExp();
        size_t hash;
        foreach (i; 0 .. ae.keys.length)
            // reduction needs associative op as keys are unsorted (use XOR)
            hash ^= mixHash(expressionHash((*ae.keys)[i]), expressionHash((*ae.values)[i]));
        return hash;
    }

    case EXP.structLiteral:
    {
        auto se = e.isStructLiteralExp();
        size_t hash;
        foreach (elem; *se.elements)
            hash = mixHash(hash, elem ? expressionHash(elem) : 0);
        return hash;
    }

    case EXP.variable:
        return cast(size_t)cast(void*) e.isVarExp().var;

    case EXP.function_:
        return cast(size_t)cast(void*) e.isFuncExp().fd;

    default:
        // no custom equals for this expression
        assert((&e.equals).funcptr is &RootObject.equals);
        // equals based on identity
        return cast(size_t)cast(void*) e;
    }
}

RootObject objectSyntaxCopy(RootObject o)
{
    if (!o)
        return null;
    if (Type t = isType(o))
        return t.syntaxCopy();
    if (Expression e = isExpression(o))
        return e.syntaxCopy();
    return o;
}

extern (C++) final class Tuple : RootObject
{
    Objects objects;

    extern (D) this() {}

    /**
    Params:
        numObjects = The initial number of objects.
    */
    extern (D) this(size_t numObjects)
    {
        objects.setDim(numObjects);
    }

    // kludge for template.isType()
    override DYNCAST dyncast() const
    {
        return DYNCAST.tuple;
    }

    override const(char)* toChars() const
    {
        return objects.toChars();
    }
}

struct TemplatePrevious
{
    TemplatePrevious* prev;
    Scope* sc;
    Objects* dedargs;
}

/***********************************************************
 * [mixin] template Identifier (parameters) [Constraint]
 * https://dlang.org/spec/template.html
 * https://dlang.org/spec/template-mixin.html
 */
extern (C++) final class TemplateDeclaration : ScopeDsymbol
{
    import dmd.root.array : Array;

    TemplateParameters* parameters;     // array of TemplateParameter's
    TemplateParameters* origParameters; // originals for Ddoc

    Expression constraint;

    // Hash table to look up TemplateInstance's of this TemplateDeclaration
    TemplateInstance[TemplateInstanceBox] instances;

    TemplateDeclaration overnext;       // next overloaded TemplateDeclaration
    TemplateDeclaration overroot;       // first in overnext list
    FuncDeclaration funcroot;           // first function in unified overload list

    Dsymbol onemember;      // if !=null then one member of this template

    bool literal;           // this template declaration is a literal
    bool ismixin;           // this is a mixin template declaration
    bool isstatic;          // this is static template declaration
    bool isTrivialAliasSeq; /// matches pattern `template AliasSeq(T...) { alias AliasSeq = T; }`
    bool isTrivialAlias;    /// matches pattern `template Alias(T) { alias Alias = qualifiers(T); }`
    bool deprecated_;       /// this template declaration is deprecated
    bool isCmacro;          /// Whether this template is a translation of a C macro
    Visibility visibility;

    // threaded list of previous instantiation attempts on stack
    TemplatePrevious* previous;

    Expression lastConstraint; /// the constraint after the last failed evaluation
    Array!Expression lastConstraintNegs; /// its negative parts
    Objects* lastConstraintTiargs; /// template instance arguments for `lastConstraint`

    extern (D) this(Loc loc, Identifier ident, TemplateParameters* parameters, Expression constraint, Dsymbols* decldefs, bool ismixin = false, bool literal = false)
    {
        super(loc, ident);
        this.dsym = DSYM.templateDeclaration;
        static if (LOG)
        {
            printf("TemplateDeclaration(this = %p, id = '%s')\n", this, ident.toChars());
        }
        version (none)
        {
            if (parameters)
                for (int i = 0; i < parameters.length; i++)
                {
                    TemplateParameter tp = (*parameters)[i];
                    //printf("\tparameter[%d] = %p\n", i, tp);
                    TemplateTypeParameter ttp = tp.isTemplateTypeParameter();
                    if (ttp)
                    {
                        printf("\tparameter[%d] = %s : %s\n", i, tp.ident.toChars(), ttp.specType ? ttp.specType.toChars() : "");
                    }
                }
        }
        this.parameters = parameters;
        this.origParameters = parameters;
        this.constraint = constraint;
        this.members = decldefs;
        this.literal = literal;
        this.ismixin = ismixin;
        this.isstatic = true;
        this.visibility = Visibility(Visibility.Kind.undefined);

        // Compute in advance for Ddoc's use
        // https://issues.dlang.org/show_bug.cgi?id=11153: ident could be NULL if parsing fails.
        if (!members || !ident)
            return;

        Dsymbol s;
        if (!oneMembers(members, s, ident) || !s)
            return;

        onemember = s;
        s.parent = this;

        /* Set isTrivialAliasSeq if this fits the pattern:
         *   template AliasSeq(T...) { alias AliasSeq = T; }
         * or set isTrivialAlias if this fits the pattern:
         *   template Alias(T) { alias Alias = qualifiers(T); }
         */
        if (!(parameters && parameters.length == 1))
            return;

        auto ad = s.isAliasDeclaration();
        if (!ad || !ad.type)
            return;

        auto ti = ad.type.isTypeIdentifier();

        if (!ti || ti.idents.length != 0)
            return;

        if (auto ttp = (*parameters)[0].isTemplateTupleParameter())
        {
            if (ti.ident is ttp.ident &&
                ti.mod == 0)
            {
                //printf("found isTrivialAliasSeq %s %s\n", s.toChars(), ad.type.toChars());
                isTrivialAliasSeq = true;
            }
        }
        else if (auto ttp = (*parameters)[0].isTemplateTypeParameter())
        {
            if (ti.ident is ttp.ident)
            {
                //printf("found isTrivialAlias %s %s\n", s.toChars(), ad.type.toChars());
                isTrivialAlias = true;
            }
        }
    }

    override TemplateDeclaration syntaxCopy(Dsymbol)
    {
        //printf("TemplateDeclaration.syntaxCopy()\n");
        TemplateParameters* p = null;
        if (parameters)
        {
            p = new TemplateParameters(parameters.length);
            foreach (i, ref param; *p)
                param = (*parameters)[i].syntaxCopy();
        }
        return new TemplateDeclaration(loc, ident, p, constraint ? constraint.syntaxCopy() : null, Dsymbol.arraySyntaxCopy(members), ismixin, literal);
    }

    /**********************************
     * Overload existing TemplateDeclaration 'this' with the new one 's'.
     * Params:
     *    s = symbol to be inserted
     * Return: true if successful; i.e. no conflict.
     */
    override bool overloadInsert(Dsymbol s)
    {
        static if (LOG)
        {
            printf("TemplateDeclaration.overloadInsert('%s')\n", s.toChars());
        }
        FuncDeclaration fd = s.isFuncDeclaration();
        if (fd)
        {
            if (funcroot)
                return funcroot.overloadInsert(fd);
            funcroot = fd;
            return funcroot.overloadInsert(this);
        }

        // https://issues.dlang.org/show_bug.cgi?id=15795
        // if candidate is an alias and its sema is not run then
        // insertion can fail because the thing it alias is not known
        if (AliasDeclaration ad = s.isAliasDeclaration())
        {
            if (s._scope)
                aliasSemantic(ad, s._scope);
            if (ad.aliassym && ad.aliassym is this)
                return false;
        }
        TemplateDeclaration td = s.toAlias().isTemplateDeclaration();
        if (!td)
            return false;

        TemplateDeclaration pthis = this;
        TemplateDeclaration* ptd;
        for (ptd = &pthis; *ptd; ptd = &(*ptd).overnext)
        {
        }

        td.overroot = this;
        *ptd = td;
        static if (LOG)
        {
            printf("\ttrue: no conflict\n");
        }
        return true;
    }

    override const(char)* kind() const
    {
        return (onemember && onemember.isAggregateDeclaration()) ? onemember.kind() : "template";
    }

    /****************************
     * Similar to `toChars`, but does not print the template constraints
     */
    const(char)* toCharsNoConstraints() const
    {
        HdrGenState hgs = { skipConstraints: true };
        OutBuffer buf;
        toCharsMaybeConstraints(this, buf, hgs);
        return buf.extractChars();
    }

    override Visibility visible() pure nothrow @nogc @safe
    {
        return visibility;
    }

    /****************************
     * Destructively get the error message from the last constraint evaluation
     * Params:
     *      tip = tip to show after printing all overloads
     */
    const(char)* getConstraintEvalError(ref const(char)* tip)
    {
        import dmd.staticcond;

        // there will be a full tree view in verbose mode, and more compact list in the usual
        const full = global.params.v.verbose;
        uint count;
        const msg = visualizeStaticCondition(constraint, lastConstraint, lastConstraintNegs[], full, count);
        scope (exit)
        {
            lastConstraint = null;
            lastConstraintTiargs = null;
            lastConstraintNegs.setDim(0);
        }
        if (!msg)
            return null;

        OutBuffer buf;

        assert(parameters && lastConstraintTiargs);
        if (parameters.length > 0)
        {
            formatParamsWithTiargs(*parameters, *lastConstraintTiargs, isVariadic() !is null, buf);
            buf.writenl();
        }
        if (!full)
        {
            // choosing singular/plural
            const s = (count == 1) ?
                "  must satisfy the following constraint:" :
                "  must satisfy one of the following constraints:";
            buf.writestring(s);
            buf.writenl();
            // the constraints
            buf.writeByte('`');
            buf.writestring(msg);
            buf.writeByte('`');
        }
        else
        {
            buf.writestring("  whose parameters have the following constraints:");
            buf.writenl();
            const sep = "  `~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`";
            buf.writestring(sep);
            buf.writenl();
            // the constraints
            buf.writeByte('`');
            buf.writestring(msg);
            buf.writeByte('`');
            buf.writestring(sep);
            tip = "not satisfied constraints are marked with `>`";
        }
        return buf.extractChars();
    }

    debug (FindExistingInstance)
    {
        __gshared uint nFound, nNotFound, nAdded, nRemoved;

        shared static ~this()
        {
            printf("debug (FindExistingInstance) nFound %u, nNotFound: %u, nAdded: %u, nRemoved: %u\n",
                   nFound, nNotFound, nAdded, nRemoved);
        }
    }

    /****************************************************
     * Given a new instance `tithis` of this TemplateDeclaration,
     * see if there already exists an instance.
     *
     * Params:
     *   tithis = template instance to check
     *   argumentList = For function templates, needed because different
     *                  `auto ref` resolutions create different instances,
     *                  even when template parameters are identical
     *
     * Returns: that existing instance, or `null` when it doesn't exist
     */
    extern (D) TemplateInstance findExistingInstance(TemplateInstance tithis, ArgumentList argumentList)
    {
        //printf("findExistingInstance() %s\n", tithis.toChars());
        tithis.fargs = argumentList.arguments;
        tithis.fnames = argumentList.names;
        auto tibox = TemplateInstanceBox(tithis);
        auto p = tibox in this.instances;
        debug (FindExistingInstance) ++(p ? nFound : nNotFound);
        //if (p) printf("\tfound %p\n", *p); else printf("\tnot found\n");
        return p ? *p : null;
    }

    /********************************************
     * Add instance ti to TemplateDeclaration's table of instances.
     * Return a handle we can use to later remove it if it fails instantiation.
     */
    extern (D) TemplateInstance addInstance(TemplateInstance ti)
    {
        //printf("addInstance() %p %s\n", instances, ti.toChars());
        auto tibox = TemplateInstanceBox(ti);
        instances[tibox] = ti;
        debug (FindExistingInstance) ++nAdded;
        return ti;
    }

    /*******************************************
     * Remove TemplateInstance from table of instances.
     * Input:
     *      handle returned by addInstance()
     */
    extern (D) void removeInstance(TemplateInstance ti)
    {
        //printf("removeInstance() %s\n", ti.toChars());
        auto tibox = TemplateInstanceBox(ti);
        debug (FindExistingInstance) ++nRemoved;
        instances.remove(tibox);
    }

    /**
     * Check if the last template parameter is a tuple one,
     * and returns it if so, else returns `null`.
     *
     * Returns:
     *   The last template parameter if it's a `TemplateTupleParameter`
     */
    extern (D) TemplateTupleParameter isVariadic()
    {
        const dim = parameters.length;
        if (dim == 0)
            return null;
        return (*parameters)[dim - 1].isTemplateTupleParameter();
    }

    extern(C++) override bool isDeprecated() const
    {
        return this.deprecated_;
    }

    /***********************************
     * We can overload templates.
     */
    override bool isOverloadable() const
    {
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

extern (C++) final class TypeDeduced : Type
{
    Type tded;
    Expressions argexps; // corresponding expressions
    Types tparams; // tparams[i].mod

    extern (D) this(Type tt, Expression e, Type tparam)
    {
        super(Tnone);
        tded = tt;
        argexps.push(e);
        tparams.push(tparam);
    }

    void update(Expression e, Type tparam)
    {
        argexps.push(e);
        tparams.push(tparam);
    }

    void update(Type tt, Expression e, Type tparam)
    {
        tded = tt;
        argexps.push(e);
        tparams.push(tparam);
    }

    MATCH matchAll(Type tt)
    {
        MATCH match = MATCH.exact;
        foreach (j, e; argexps)
        {
            assert(e);
            if (e == emptyArrayElement)
                continue;

            Type t = tt.addMod(tparams[j].mod).substWildTo(MODFlags.const_);

            MATCH m = e.implicitConvTo(t);
            if (match > m)
                match = m;
            if (match == MATCH.nomatch)
                break;
        }
        return match;
    }
}


/* ======================== Type ============================================ */

/****
 * Given an identifier, figure out which TemplateParameter it is.
 * Return IDX_NOTFOUND if not found.
 */
size_t templateIdentifierLookup(Identifier id, TemplateParameters* parameters)
{
    for (size_t i = 0; i < parameters.length; i++)
    {
        TemplateParameter tp = (*parameters)[i];
        if (tp.ident.equals(id))
            return i;
    }
    return IDX_NOTFOUND;
}

size_t templateParameterLookup(Type tparam, TemplateParameters* parameters)
{
    if (TypeIdentifier tident = tparam.isTypeIdentifier())
    {
        //printf("\ttident = '%s'\n", tident.toChars());
        return templateIdentifierLookup(tident.ident, parameters);
    }
    return IDX_NOTFOUND;
}

private auto X(T, U)(T m, U n)
{
    return (m << 4) | n;
}

ubyte deduceWildHelper(Type t, Type* at, Type tparam)
{
    if ((tparam.mod & MODFlags.wild) == 0)
        return 0;

    *at = null;

    switch (X(tparam.mod, t.mod))
    {
    case X(MODFlags.wild, 0):
    case X(MODFlags.wild, MODFlags.const_):
    case X(MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.wildconst, 0):
    case X(MODFlags.wildconst, MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.wildconst, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.immutable_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.const_):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.immutable_):
        {
            ubyte wm = (t.mod & ~MODFlags.shared_);
            if (wm == 0)
                wm = MODFlags.mutable;
            ubyte m = (t.mod & (MODFlags.const_ | MODFlags.immutable_)) | (tparam.mod & t.mod & MODFlags.shared_);
            *at = t.unqualify(m);
            return wm;
        }
    case X(MODFlags.wild, MODFlags.wild):
    case X(MODFlags.wild, MODFlags.wildconst):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.wildconst, MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.wildconst):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wild, MODFlags.shared_ | MODFlags.wildconst):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wild):
    case X(MODFlags.shared_ | MODFlags.wildconst, MODFlags.shared_ | MODFlags.wildconst):
        {
            *at = t.unqualify(tparam.mod & t.mod);
            return MODFlags.wild;
        }
    default:
        return 0;
    }
}



/***********************************************************
 * Check whether the type t representation relies on one or more the template parameters.
 * Params:
 *      t           = Tested type, if null, returns false.
 *      tparams     = Template parameters.
 *      iStart      = Start index of tparams to limit the tested parameters. If it's
 *                    nonzero, tparams[0..iStart] will be excluded from the test target.
 */
bool reliesOnTident(Type t, TemplateParameters* tparams, size_t iStart = 0)
{
    return reliesOnTemplateParameters(t, (*tparams)[0 .. tparams.length]);
}

/***********************************************************
 * Check whether the type t representation relies on one or more the template parameters.
 * Params:
 *      t           = Tested type, if null, returns false.
 *      tparams     = Template parameters.
 */
bool reliesOnTemplateParameters(Type t, TemplateParameter[] tparams)
{
    bool visitVector(TypeVector t)
    {
        return t.basetype.reliesOnTemplateParameters(tparams);
    }

    bool visitAArray(TypeAArray t)
    {
        return t.next.reliesOnTemplateParameters(tparams) ||
               t.index.reliesOnTemplateParameters(tparams);
    }

    bool visitFunction(TypeFunction t)
    {
        foreach (i, fparam; t.parameterList)
        {
            if (fparam.type.reliesOnTemplateParameters(tparams))
                return true;
        }
        return t.next.reliesOnTemplateParameters(tparams);
    }

    bool visitIdentifier(TypeIdentifier t)
    {
        foreach (tp; tparams)
        {
            if (tp.ident.equals(t.ident))
                return true;
        }
        return false;
    }

    bool visitInstance(TypeInstance t)
    {
        foreach (tp; tparams)
        {
            if (t.tempinst.name == tp.ident)
                return true;
        }

        if (t.tempinst.tiargs)
            foreach (arg; *t.tempinst.tiargs)
            {
                if (Type ta = isType(arg))
                {
                    if (ta.reliesOnTemplateParameters(tparams))
                        return true;
                }
            }

        return false;
    }

    bool visitTypeof(TypeTypeof t)
    {
        //printf("TypeTypeof.reliesOnTemplateParameters('%s')\n", t.toChars());
        return t.exp.reliesOnTemplateParameters(tparams);
    }

    bool visitTuple(TypeTuple t)
    {
        if (t.arguments)
            foreach (arg; *t.arguments)
            {
                if (arg.type.reliesOnTemplateParameters(tparams))
                    return true;
            }

        return false;
    }

    if (!t)
        return false;

    Type tb = t.toBasetype();
    switch (tb.ty)
    {
        case Tvector:   return visitVector(tb.isTypeVector());
        case Taarray:   return visitAArray(tb.isTypeAArray());
        case Tfunction: return visitFunction(tb.isTypeFunction());
        case Tident:    return visitIdentifier(tb.isTypeIdentifier());
        case Tinstance: return visitInstance(tb.isTypeInstance());
        case Ttypeof:   return visitTypeof(tb.isTypeTypeof());
        case Ttuple:    return visitTuple(tb.isTypeTuple());
        case Tenum:     return false;
        default:        return tb.nextOf().reliesOnTemplateParameters(tparams);
    }
}

/***********************************************************
 * Check whether the expression representation relies on one or more the template parameters.
 * Params:
 *      e           = expression to test
 *      tparams     = Template parameters.
 * Returns:
 *      true if it does
 */
private bool reliesOnTemplateParameters(Expression e, TemplateParameter[] tparams)
{
    extern (C++) final class ReliesOnTemplateParameters : Visitor
    {
        alias visit = Visitor.visit;
    public:
        TemplateParameter[] tparams;
        bool result;

        extern (D) this(TemplateParameter[] tparams) @safe
        {
            this.tparams = tparams;
        }

        override void visit(Expression e)
        {
            //printf("Expression.reliesOnTemplateParameters('%s')\n", e.toChars());
        }

        override void visit(IdentifierExp e)
        {
            //printf("IdentifierExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            foreach (tp; tparams)
            {
                if (e.ident == tp.ident)
                {
                    result = true;
                    return;
                }
            }
        }

        override void visit(TupleExp e)
        {
            //printf("TupleExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (e.exps)
            {
                foreach (ea; *e.exps)
                {
                    ea.accept(this);
                    if (result)
                        return;
                }
            }
        }

        override void visit(ArrayLiteralExp e)
        {
            //printf("ArrayLiteralExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (e.elements)
            {
                foreach (el; *e.elements)
                {
                    el.accept(this);
                    if (result)
                        return;
                }
            }
        }

        override void visit(AssocArrayLiteralExp e)
        {
            //printf("AssocArrayLiteralExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            foreach (ek; *e.keys)
            {
                ek.accept(this);
                if (result)
                    return;
            }
            foreach (ev; *e.values)
            {
                ev.accept(this);
                if (result)
                    return;
            }
        }

        override void visit(StructLiteralExp e)
        {
            //printf("StructLiteralExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (e.elements)
            {
                foreach (ea; *e.elements)
                {
                    ea.accept(this);
                    if (result)
                        return;
                }
            }
        }

        override void visit(TypeExp e)
        {
            //printf("TypeExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            result = e.type.reliesOnTemplateParameters(tparams);
        }

        override void visit(NewExp e)
        {
            //printf("NewExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (e.placement)
                e.placement.accept(this);
            if (e.thisexp)
                e.thisexp.accept(this);
            result = e.newtype.reliesOnTemplateParameters(tparams);
            if (!result && e.arguments)
            {
                foreach (ea; *e.arguments)
                {
                    ea.accept(this);
                    if (result)
                        return;
                }
            }
        }

        override void visit(NewAnonClassExp e)
        {
            //printf("NewAnonClassExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            result = true;
        }

        override void visit(FuncExp e)
        {
            //printf("FuncExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            result = true;
        }

        override void visit(TypeidExp e)
        {
            //printf("TypeidExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (auto ea = isExpression(e.obj))
                ea.accept(this);
            else if (auto ta = isType(e.obj))
                result = ta.reliesOnTemplateParameters(tparams);
        }

        override void visit(TraitsExp e)
        {
            //printf("TraitsExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            if (e.args)
            {
                foreach (oa; *e.args)
                {
                    if (auto ea = isExpression(oa))
                        ea.accept(this);
                    else if (auto ta = isType(oa))
                        result = ta.reliesOnTemplateParameters(tparams);
                    if (result)
                        return;
                }
            }
        }

        override void visit(IsExp e)
        {
            //printf("IsExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            result = e.targ.reliesOnTemplateParameters(tparams);
        }

        override void visit(UnaExp e)
        {
            //printf("UnaExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            e.e1.accept(this);
        }

        override void visit(DotTemplateInstanceExp e)
        {
            //printf("DotTemplateInstanceExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            visit(e.isUnaExp());
            if (!result && e.ti.tiargs)
            {
                foreach (oa; *e.ti.tiargs)
                {
                    if (auto ea = isExpression(oa))
                        ea.accept(this);
                    else if (auto ta = isType(oa))
                        result = ta.reliesOnTemplateParameters(tparams);
                    if (result)
                        return;
                }
            }
        }

        override void visit(CallExp e)
        {
            //printf("CallExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            visit(e.isUnaExp());
            if (!result && e.arguments)
            {
                foreach (ea; *e.arguments)
                {
                    ea.accept(this);
                    if (result)
                        return;
                }
            }
        }

        override void visit(CastExp e)
        {
            //printf("CallExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            visit(e.isUnaExp());
            // e.to can be null for cast() with no type
            if (!result && e.to)
                result = e.to.reliesOnTemplateParameters(tparams);
        }

        override void visit(SliceExp e)
        {
            //printf("SliceExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            visit(e.isUnaExp());
            if (!result && e.lwr)
                e.lwr.accept(this);
            if (!result && e.upr)
                e.upr.accept(this);
        }

        override void visit(IntervalExp e)
        {
            //printf("IntervalExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            e.lwr.accept(this);
            if (!result)
                e.upr.accept(this);
        }

        override void visit(ArrayExp e)
        {
            //printf("ArrayExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            visit(e.isUnaExp());
            if (!result && e.arguments)
            {
                foreach (ea; *e.arguments)
                    ea.accept(this);
            }
        }

        override void visit(BinExp e)
        {
            //printf("BinExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            e.e1.accept(this);
            if (!result)
                e.e2.accept(this);
        }

        override void visit(CondExp e)
        {
            //printf("BinExp.reliesOnTemplateParameters('%s')\n", e.toChars());
            e.econd.accept(this);
            if (!result)
                visit(e.isBinExp());
        }
    }

    scope ReliesOnTemplateParameters v = new ReliesOnTemplateParameters(tparams);
    e.accept(v);
    return v.result;
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateParameter
 */
extern (C++) class TemplateParameter : ASTNode
{
    Loc loc;
    Identifier ident;

    /* True if this is a part of precedent parameter specialization pattern.
     *
     *  template A(T : X!TL, alias X, TL...) {}
     *  // X and TL are dependent template parameter
     *
     * A dependent template parameter should return MATCH.exact in matchArg()
     * to respect the match level of the corresponding precedent parameter.
     */
    bool dependent;

    /* ======================== TemplateParameter =============================== */
    extern (D) this(Loc loc, Identifier ident) @safe
    {
        this.loc = loc;
        this.ident = ident;
    }

    TemplateTypeParameter isTemplateTypeParameter()
    {
        return null;
    }

    TemplateValueParameter isTemplateValueParameter()
    {
        return null;
    }

    TemplateAliasParameter isTemplateAliasParameter()
    {
        return null;
    }

    TemplateThisParameter isTemplateThisParameter()
    {
        return null;
    }

    TemplateTupleParameter isTemplateTupleParameter()
    {
        return null;
    }

    abstract TemplateParameter syntaxCopy();

    abstract bool declareParameter(Scope* sc);

    abstract void print(RootObject oarg, RootObject oded);

    abstract RootObject specialization();

    abstract RootObject defaultArg(Loc instLoc, Scope* sc);

    abstract bool hasDefaultArg();

    override const(char)* toChars() const
    {
        return this.ident.toChars();
    }

    override DYNCAST dyncast() const
    {
        return DYNCAST.templateparameter;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateTypeParameter
 * Syntax:
 *  ident : specType = defaultType
 */
extern (C++) class TemplateTypeParameter : TemplateParameter
{
    Type specType;      // if !=null, this is the type specialization
    Type defaultType;

    extern (D) __gshared Type tdummy = null;

    extern (D) this(Loc loc, Identifier ident, Type specType, Type defaultType) @safe
    {
        super(loc, ident);
        this.specType = specType;
        this.defaultType = defaultType;
    }

    override final TemplateTypeParameter isTemplateTypeParameter()
    {
        return this;
    }

    override TemplateTypeParameter syntaxCopy()
    {
        return new TemplateTypeParameter(loc, ident, specType ? specType.syntaxCopy() : null, defaultType ? defaultType.syntaxCopy() : null);
    }

    override final bool declareParameter(Scope* sc)
    {
        //printf("TemplateTypeParameter.declareParameter('%s')\n", ident.toChars());
        auto ti = new TypeIdentifier(loc, ident);
        Declaration ad = new AliasDeclaration(loc, ident, ti);
        return sc.insert(ad) !is null;
    }

    override final void print(RootObject oarg, RootObject oded)
    {
        printf(" %s\n", ident.toChars());

        Type t = isType(oarg);
        Type ta = isType(oded);
        assert(ta);

        if (specType)
            printf("\tSpecialization: %s\n", specType.toChars());
        if (defaultType)
            printf("\tDefault:        %s\n", defaultType.toChars());
        printf("\tParameter:       %s\n", t ? t.toChars() : "NULL");
        printf("\tDeduced Type:   %s\n", ta.toChars());
    }

    override final RootObject specialization()
    {
        return specType;
    }

    override final RootObject defaultArg(Loc instLoc, Scope* sc)
    {
        Type t = defaultType;
        if (t)
        {
            t = t.syntaxCopy();
            t = t.typeSemantic(loc, sc); // use the parameter loc
        }
        return t;
    }

    override final bool hasDefaultArg()
    {
        return defaultType !is null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateThisParameter
 * Syntax:
 *  this ident : specType = defaultType
 */
extern (C++) final class TemplateThisParameter : TemplateTypeParameter
{
    extern (D) this(Loc loc, Identifier ident, Type specType, Type defaultType) @safe
    {
        super(loc, ident, specType, defaultType);
    }

    override TemplateThisParameter isTemplateThisParameter()
    {
        return this;
    }

    override TemplateThisParameter syntaxCopy()
    {
        return new TemplateThisParameter(loc, ident, specType ? specType.syntaxCopy() : null, defaultType ? defaultType.syntaxCopy() : null);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateValueParameter
 * Syntax:
 *  valType ident : specValue = defaultValue
 */
extern (C++) final class TemplateValueParameter : TemplateParameter
{
    Type valType;
    Expression specValue;
    Expression defaultValue;

    extern (D) __gshared Expression[void*] edummies;

    extern (D) this(Loc loc, Identifier ident, Type valType,
        Expression specValue, Expression defaultValue) @safe
    {
        super(loc, ident);
        this.valType = valType;
        this.specValue = specValue;
        this.defaultValue = defaultValue;
    }

    override TemplateValueParameter isTemplateValueParameter()
    {
        return this;
    }

    override TemplateValueParameter syntaxCopy()
    {
        return new TemplateValueParameter(loc, ident,
            valType.syntaxCopy(),
            specValue ? specValue.syntaxCopy() : null,
            defaultValue ? defaultValue.syntaxCopy() : null);
    }

    override bool declareParameter(Scope* sc)
    {
        /*
            Do type semantic earlier.

            This means for certain erroneous value parameters
            their "type" can be known earlier and thus a better
            error message given.

            For example:
            `template test(x* x) {}`
            now yields "undefined identifier" rather than the opaque
            "variable `x` is used as a type".
         */
        if (valType)
            valType = valType.typeSemantic(loc, sc);
        auto v = new VarDeclaration(loc, valType, ident, null);
        v.storage_class = STC.templateparameter;
        return sc.insert(v) !is null;
    }

    override void print(RootObject oarg, RootObject oded)
    {
        printf(" %s\n", ident.toChars());
        Expression ea = isExpression(oded);
        if (specValue)
            printf("\tSpecialization: %s\n", specValue.toChars());
        printf("\tParameter Value: %s\n", ea ? ea.toChars() : "NULL");
    }

    override RootObject specialization()
    {
        return specValue;
    }

    override RootObject defaultArg(Loc instLoc, Scope* sc)
    {
        Expression e = defaultValue;
        if (!e)
            return null;

        e = e.syntaxCopy();
        Scope* sc2 = sc.push();
        sc2.inDefaultArg = true;
        e = e.expressionSemantic(sc2);
        sc2.pop();
        if (e is null)
            return null;
        if (auto te = e.isTemplateExp())
        {
            assert(sc && sc.tinst);
            if (te.td == sc.tinst.tempdecl)
            {
                // defaultValue is a reference to its template declaration
                // i.e: `template T(int arg = T)`
                // Raise error now before calling resolveProperties otherwise we'll
                // start looping on the expansion of the template instance.
                auto td = sc.tinst.tempdecl;
                .error(td.loc, "%s `%s` recursive template expansion", td.kind, td.toPrettyChars);
                return ErrorExp.get();
            }
        }
        if ((e = resolveProperties(sc, e)) is null)
            return null;
        e = e.resolveLoc(instLoc, sc); // use the instantiated loc
        e = e.optimize(WANTvalue);

        return e;
    }

    override bool hasDefaultArg()
    {
        return defaultValue !is null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateAliasParameter
 * Syntax:
 *  specType ident : specAlias = defaultAlias
 */
extern (C++) final class TemplateAliasParameter : TemplateParameter
{
    Type specType;
    RootObject specAlias;
    RootObject defaultAlias;

    extern (D) __gshared Dsymbol sdummy = null;

    extern (D) this(Loc loc, Identifier ident, Type specType, RootObject specAlias, RootObject defaultAlias) @safe
    {
        super(loc, ident);
        this.specType = specType;
        this.specAlias = specAlias;
        this.defaultAlias = defaultAlias;
    }

    override TemplateAliasParameter isTemplateAliasParameter()
    {
        return this;
    }

    override TemplateAliasParameter syntaxCopy()
    {
        return new TemplateAliasParameter(loc, ident, specType ? specType.syntaxCopy() : null, objectSyntaxCopy(specAlias), objectSyntaxCopy(defaultAlias));
    }

    override bool declareParameter(Scope* sc)
    {
        auto ti = new TypeIdentifier(loc, ident);
        Declaration ad = new AliasDeclaration(loc, ident, ti);
        return sc.insert(ad) !is null;
    }

    override void print(RootObject oarg, RootObject oded)
    {
        printf(" %s\n", ident.toChars());
        Dsymbol sa = isDsymbol(oded);
        assert(sa);
        printf("\tParameter alias: %s\n", sa.toChars());
    }

    override RootObject specialization()
    {
        return specAlias;
    }

    override RootObject defaultArg(Loc instLoc, Scope* sc)
    {
        RootObject da = defaultAlias;
        if (auto ta = isType(defaultAlias))
        {
            switch (ta.ty)
            {
            // If the default arg is a template, instantiate for each type
            case Tinstance :
            // same if the default arg is a mixin, traits, typeof
            // since the content might rely on a previous parameter
            // (https://issues.dlang.org/show_bug.cgi?id=23686)
            case Tmixin, Ttypeof, Ttraits :
                da = ta.syntaxCopy();
                break;
            default:
            }
        }

        RootObject o = aliasParameterSemantic(loc, sc, da, null); // use the parameter loc
        return o;
    }

    override bool hasDefaultArg()
    {
        return defaultAlias !is null;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#TemplateSequenceParameter
 * Syntax:
 *  ident ...
 */
extern (C++) final class TemplateTupleParameter : TemplateParameter
{
    extern (D) this(Loc loc, Identifier ident) @safe
    {
        super(loc, ident);
    }

    override TemplateTupleParameter isTemplateTupleParameter()
    {
        return this;
    }

    override TemplateTupleParameter syntaxCopy()
    {
        return new TemplateTupleParameter(loc, ident);
    }

    override bool declareParameter(Scope* sc)
    {
        auto ti = new TypeIdentifier(loc, ident);
        Declaration ad = new AliasDeclaration(loc, ident, ti);
        return sc.insert(ad) !is null;
    }

    override void print(RootObject oarg, RootObject oded)
    {
        printf(" %s... [", ident.toChars());
        Tuple v = isTuple(oded);
        assert(v);

        //printf("|%d| ", v.objects.length);
        foreach (i, o; v.objects)
        {
            if (i)
                printf(", ");

            Dsymbol sa = isDsymbol(o);
            if (sa)
                printf("alias: %s", sa.toChars());
            Type ta = isType(o);
            if (ta)
                printf("type: %s", ta.toChars());
            Expression ea = isExpression(o);
            if (ea)
                printf("exp: %s", ea.toChars());

            assert(!isTuple(o)); // no nested Tuple arguments
        }
        printf("]\n");
    }

    override RootObject specialization()
    {
        return null;
    }

    override RootObject defaultArg(Loc instLoc, Scope* sc)
    {
        return null;
    }

    override bool hasDefaultArg()
    {
        return false;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/***********************************************************
 * https://dlang.org/spec/template.html#explicit_tmp_instantiation
 * Given:
 *  foo!(args) =>
 *      name = foo
 *      tiargs = args
 */
extern (C++) class TemplateInstance : ScopeDsymbol
{
    Identifier name;

    // Array of Types/Expressions of template
    // instance arguments [int*, char, 10*10]
    Objects* tiargs;

    // Array of Types/Expressions corresponding
    // to TemplateDeclaration.parameters
    // [int, char, 100]
    Objects tdtypes;

    // Modules imported by this template instance
    Modules importedModules;

    Dsymbol tempdecl;           // referenced by foo.bar.abc
    Dsymbol enclosing;          // if referencing local symbols, this is the context
    Dsymbol aliasdecl;          // !=null if instance is an alias for its sole member

    /**
    If this is not null and it has a value that is not the current object,
     then this field points to an existing template instance
     and that object has been duplicated into us.

    If this object is a duplicate,
     the ``memberOf`` field will be set to a root module (passed on CLI).

    This information is useful to deduplicate analysis that may occur
     after semantic 3 has completed.

    See_Also: memberOf
    */
    TemplateInstance inst;

    ScopeDsymbol argsym;        // argument symbol table
    size_t hash;                // cached result of toHash()

    /// For function template, these are the function fnames(name and loc of it) and arguments
    /// Relevant because different resolutions of `auto ref` parameters
    /// create different template instances even with the same template arguments
    Expressions* fargs;
    ArgumentLabels* fnames;

    TemplateInstances* deferred;

    /**
    If this is not null then this template instance appears in a root module's members.

    Note:   This is not useful for determining duplication status of this template instance.
            Use the field ``inst`` for determining if a template instance has been duplicated into this object.

    See_Also: inst
    */
    Module memberOf;

    // Used to determine the instance needs code generation.
    // Note that these are inaccurate until semantic analysis phase completed.
    TemplateInstance tinst;     // enclosing template instance
    TemplateInstance tnext;     // non-first instantiated instances
    Module minst;               // the top module that instantiated this instance

    private ushort _nest;       // for recursive pretty printing detection, 3 MSBs reserved for flags (below)
    ubyte inuse;                // for recursive expansion detection

    private enum Flag : uint
    {
        semantictiargsdone = 1u << (_nest.sizeof * 8 - 1), // MSB of _nest
        havetempdecl = semantictiargsdone >> 1,
        gagged = semantictiargsdone >> 2,
        available = gagged - 1 // always last flag minus one, 1s for all available bits
    }

    extern(D) final @safe @property pure nothrow @nogc
    {
        ushort nest() const { return _nest & Flag.available; }
        void nestUp() { assert(nest() < Flag.available); ++_nest; }
        void nestDown() { assert(nest() > 0); --_nest; }
        /// has semanticTiargs() been done?
        bool semantictiargsdone() const { return (_nest & Flag.semantictiargsdone) != 0; }
        void semantictiargsdone(bool x)
        {
            if (x) _nest |= Flag.semantictiargsdone;
            else _nest &= ~Flag.semantictiargsdone;
        }
        /// if used second constructor
        bool havetempdecl() const { return (_nest & Flag.havetempdecl) != 0; }
        void havetempdecl(bool x)
        {
            if (x) _nest |= Flag.havetempdecl;
            else _nest &= ~Flag.havetempdecl;
        }
        /// if the instantiation is done with error gagging
        bool gagged() const { return (_nest & Flag.gagged) != 0; }
        void gagged(bool x)
        {
            if (x) _nest |= Flag.gagged;
            else _nest &= ~Flag.gagged;
        }
    }

    extern (D) this(Loc loc, Identifier ident, Objects* tiargs) scope
    {
        super(loc, null);
        static if (LOG)
        {
            printf("TemplateInstance(this = %p, ident = '%s')\n", this, ident ? ident.toChars() : "null");
        }
        this.dsym = DSYM.templateInstance;
        this.name = ident;
        this.tiargs = tiargs;
    }

    /*****************
     * This constructor is only called when we figured out which function
     * template to instantiate.
     */
    extern (D) this(Loc loc, TemplateDeclaration td, Objects* tiargs) scope
    {
        super(loc, null);
        static if (LOG)
        {
            printf("TemplateInstance(this = %p, tempdecl = '%s')\n", this, td.toChars());
        }
        this.dsym = DSYM.templateInstance;
        this.name = td.ident;
        this.tiargs = tiargs;
        this.tempdecl = td;
        this.semantictiargsdone = true;
        this.havetempdecl = true;
        assert(tempdecl._scope);
    }

    extern (D) static Objects* arraySyntaxCopy(Objects* objs)
    {
        Objects* a = null;
        if (objs)
        {
            a = new Objects(objs.length);
            foreach (i, o; *objs)
                (*a)[i] = objectSyntaxCopy(o);
        }
        return a;
    }

    override TemplateInstance syntaxCopy(Dsymbol s)
    {
        TemplateInstance ti = s ? cast(TemplateInstance)s : new TemplateInstance(loc, name, null);
        ti.tiargs = arraySyntaxCopy(tiargs);
        TemplateDeclaration td;
        if (inst && tempdecl && (td = tempdecl.isTemplateDeclaration()) !is null)
            td.ScopeDsymbol.syntaxCopy(ti);
        else
            ScopeDsymbol.syntaxCopy(ti);
        return ti;
    }

    // resolve real symbol
    override final Dsymbol toAlias()
    {
        static if (LOG)
        {
            printf("TemplateInstance.toAlias()\n");
        }
        if (!inst)
        {
            // Maybe we can resolve it
            if (_scope)
            {
                dsymbolSemantic(this, _scope);
            }
            if (!inst)
            {
                .error(loc, "%s `%s` cannot resolve forward reference", kind, toPrettyChars);
                errors = true;
                return this;
            }
        }

        if (inst != this)
            return inst.toAlias();

        if (aliasdecl)
        {
            return aliasdecl.toAlias();
        }

        return inst;
    }

    override const(char)* kind() const
    {
        return "template instance";
    }

    override final const(char)* toPrettyCharsHelper()
    {
        OutBuffer buf;
        toCBufferInstance(this, buf, true);
        return buf.extractChars();
    }

    /**************************************
     * Given an error instantiating the TemplateInstance,
     * give the nested TemplateInstance instantiations that got
     * us here. Those are a list threaded into the nested scopes.
     * Params:
     *  cl = classification of this trace as printing either errors or deprecations
     *  max_shown = maximum number of trace elements printed (controlled with -v/-verror-limit)
     */
    extern(D) final void printInstantiationTrace(Classification cl = Classification.error,
                                                 const(uint) max_shown = global.params.v.errorSupplementCount())
    {
        if (global.gag)
            return;

        // Print full trace for verbose mode, otherwise only short traces
        const(char)* format = "instantiated from here: `%s`";

        // This returns a function pointer
        scope printFn = () {
            final switch (cl)
            {
                case Classification.error:
                    return &errorSupplemental;
                case Classification.deprecation:
                    return &deprecationSupplemental;
                case Classification.gagged, Classification.tip, Classification.warning:
                    assert(0);
            }
        }();

        // determine instantiation depth and number of recursive instantiations
        int n_instantiations = 1;
        int n_totalrecursions = 0;
        for (TemplateInstance cur = this; cur; cur = cur.tinst)
        {
            ++n_instantiations;
            // Set error here as we don't want it to depend on the number of
            // entries that are being printed.
            if (cl == Classification.error ||
                (cl == Classification.warning && global.params.useWarnings == DiagnosticReporting.error) ||
                (cl == Classification.deprecation && global.params.useDeprecated == DiagnosticReporting.error))
                cur.errors = true;

            // If two instantiations use the same declaration, they are recursive.
            // (this works even if they are instantiated from different places in the
            // same template).
            // In principle, we could also check for multiple-template recursion, but it's
            // probably not worthwhile.
            if (cur.tinst && cur.tempdecl && cur.tinst.tempdecl && cur.tempdecl.loc.equals(cur.tinst.tempdecl.loc))
                ++n_totalrecursions;
        }

        if (n_instantiations <= max_shown)
        {
            for (TemplateInstance cur = this; cur; cur = cur.tinst)
                printFn(cur.loc, format, cur.toErrMsg());
        }
        else if (n_instantiations - n_totalrecursions <= max_shown)
        {
            // By collapsing recursive instantiations into a single line,
            // we can stay under the limit.
            int recursionDepth = 0;
            for (TemplateInstance cur = this; cur; cur = cur.tinst)
            {
                if (cur.tinst && cur.tempdecl && cur.tinst.tempdecl && cur.tempdecl.loc.equals(cur.tinst.tempdecl.loc))
                {
                    ++recursionDepth;
                }
                else
                {
                    if (recursionDepth)
                        printFn(cur.loc, "%d recursive instantiations from here: `%s`", recursionDepth + 2, cur.toChars());
                    else
                        printFn(cur.loc, format, cur.toChars());
                    recursionDepth = 0;
                }
            }
        }
        else
        {
            // Even after collapsing the recursions, the depth is too deep.
            // Just display the first few and last few instantiations.
            uint i = 0;
            for (TemplateInstance cur = this; cur; cur = cur.tinst)
            {
                if (i == max_shown / 2)
                    printFn(cur.loc, "... (%d instantiations, -v to show) ...", n_instantiations - max_shown);

                if (i < max_shown / 2 || i >= n_instantiations - max_shown + max_shown / 2)
                    printFn(cur.loc, format, cur.toChars());
                ++i;
            }
        }
    }

    /*************************************
     * Lazily generate identifier for template instance.
     * This is because 75% of the ident's are never needed.
     */
    override final Identifier getIdent()
    {
        if (!ident && inst && !errors)
            ident = genIdent(tiargs); // need an identifier for name mangling purposes.
        return ident;
    }

    /*************************************
     * Compare proposed template instantiation with existing template instantiation.
     * Note that this is not commutative because of the auto ref check.
     * Params:
     *  ti = existing template instantiation
     * Returns:
     *  true for match
     */
    final bool equalsx(TemplateInstance ti)
    {
        //printf("this = %p, ti = %p\n", this, ti);
        assert(tdtypes.length == ti.tdtypes.length);

        // Nesting must match
        if (enclosing != ti.enclosing)
        {
            //printf("test2 enclosing %s ti.enclosing %s\n", enclosing ? enclosing.toChars() : "", ti.enclosing ? ti.enclosing.toChars() : "");
            return false;
        }
        //printf("parent = %s, ti.parent = %s\n", parent.toPrettyChars(), ti.parent.toPrettyChars());

        if (!arrayObjectMatch(tdtypes, ti.tdtypes))
            return false;

        /* Template functions may have different instantiations based on
         * "auto ref" parameters.
         */
        auto fd = ti.toAlias().isFuncDeclaration();
        if (!fd)
            return true;
        if (fd.errors)
            return true;

        auto resolvedArgs = fd.type.isTypeFunction().resolveNamedArgs(
            ArgumentList(this.fargs, this.fnames), null);

        // resolvedArgs can be null when there's an error: fail_compilation/fail14669.d
        // In that case, equalsx returns true to prevent endless template instantiations
        // However, it can also mean the function was explicitly instantiated
        // without function arguments: fail_compilation/fail14669
        // Hence the following check:
        if (this.fargs && !resolvedArgs)
            return true;

        Expression[] args = resolvedArgs ? (*resolvedArgs)[] : [];

        auto fparameters = fd.getParameterList();
        size_t nfparams = fparameters.length;   // Num function parameters
        for (size_t j = 0; j < nfparams; j++)
        {
            Parameter fparam = fparameters[j];
            if (!(fparam.storageClass & STC.autoref) )      // if "auto ref"
                continue;

            Expression farg = (j < args.length) ? args[j] : fparam.defaultArg;
            // resolveNamedArgs strips trailing nulls / default params
            // when it doesn't anymore, the ternary can be replaced with:
            // assert(j < resolvedArgs.length);
            if (!farg)
                farg = fparam.defaultArg;
            if (!farg)
                return false;
            if (farg.isLvalue())
            {
                if (!(fparam.storageClass & STC.ref_))
                    return false; // auto ref's don't match
            }
            else
            {
                if (fparam.storageClass & STC.ref_)
                    return false; // auto ref's don't match
            }
        }
        return true;
    }

    extern (D) final size_t toHash()
    {
        if (!hash)
        {
            hash = cast(size_t)cast(void*)enclosing;
            hash += arrayObjectHash(tdtypes);
            hash += hash == 0;
        }
        return hash;
    }

    /**********************************************
     * Confirm s is a valid template, then store it.
     * Input:
     *      sc
     *      s   candidate symbol of template. It may be:
     *          TemplateDeclaration
     *          FuncDeclaration with findTemplateDeclRoot() != NULL
     *          OverloadSet which contains candidates
     * Returns:
     *      true if updating succeeds.
     */
    extern (D) final bool updateTempDecl(Scope* sc, Dsymbol s)
    {
        if (!s)
            return tempdecl !is null;

        Identifier id = name;
        s = s.toAlias();

        /* If an OverloadSet, look for a unique member that is a template declaration
         */
        if (OverloadSet os = s.isOverloadSet())
        {
            s = null;
            foreach (s2; os.a)
            {
                if (FuncDeclaration f = s2.isFuncDeclaration())
                    s2 = f.findTemplateDeclRoot();
                else
                    s2 = s2.isTemplateDeclaration();
                if (s2)
                {
                    if (s)
                    {
                        tempdecl = os;
                        return true;
                    }
                    s = s2;
                }
            }
            if (!s)
            {
                .error(loc, "%s `%s` template `%s` is not defined", kind, toPrettyChars, id.toChars());
                return false;
            }
        }

        if (OverDeclaration od = s.isOverDeclaration())
        {
            tempdecl = od; // TODO: more strict check
            return true;
        }

        /* It should be a TemplateDeclaration, not some other symbol
         */
        if (FuncDeclaration f = s.isFuncDeclaration())
            tempdecl = f.findTemplateDeclRoot();
        else
            tempdecl = s.isTemplateDeclaration();

        // We're done
        if (tempdecl)
            return true;

        // Error already issued, just return `false`
        if (!s.parent && global.errors)
            return false;

        if (!s.parent && s.getType())
        {
            Dsymbol s2 = s.getType().toDsymbol(sc);
            if (!s2)
            {
                .error(loc, "`%s` is not a valid template instance, because `%s` is not a template declaration but a type (`%s == %s`)", toChars(), id.toChars(), id.toChars(), s.getType.kind());
                return false;
            }
            // because s can be the alias created for a TemplateParameter
            const AliasDeclaration ad = s.isAliasDeclaration();
            version (none)
            {
                if (ad && ad.isAliasedTemplateParameter())
                    printf("`%s` is an alias created from a template parameter\n", s.toChars());
            }
            if (!ad || !ad.isAliasedTemplateParameter())
                s = s2;
        }

        TemplateInstance ti = s.parent ? s.parent.isTemplateInstance() : null;

        /* This avoids the VarDeclaration.toAlias() which runs semantic() too soon
         */
        static bool matchId(TemplateInstance ti, Identifier id)
        {
            if (ti.aliasdecl && ti.aliasdecl.isVarDeclaration())
                return ti.aliasdecl.isVarDeclaration().ident == id;
            return ti.toAlias().ident == id;
        }

        if (ti && (ti.name == s.ident || matchId(ti, s.ident)) && ti.tempdecl)
        {
            /* This is so that one can refer to the enclosing
             * template, even if it has the same name as a member
             * of the template, if it has a !(arguments)
             */
            TemplateDeclaration td = ti.tempdecl.isTemplateDeclaration();
            assert(td);
            if (td.overroot) // if not start of overloaded list of TemplateDeclaration's
                td = td.overroot; // then get the start
            tempdecl = td;
            return true;
        }
        else
        {
            .error(loc, "%s `%s` `%s` is not a template declaration, it is a %s", kind, toPrettyChars, id.toChars(), s.kind());
            return false;
        }
    }

    /**********************************
     * Run semantic of tiargs as arguments of template.
     * Input:
     *      loc
     *      sc
     *      tiargs  array of template arguments
     *      flags   1: replace const variables with their initializers
     *              2: don't devolve Parameter to Type
     *      atd     tuple being optimized. If found, it's not expanded here
     *              but in AliasAssign semantic.
     * Returns:
     *      false if one or more arguments have errors.
     */
    extern (D) static bool semanticTiargs(Loc loc, Scope* sc, Objects* tiargs, int flags, TupleDeclaration atd = null)
    {
        // Run semantic on each argument, place results in tiargs[]
        //printf("+TemplateInstance.semanticTiargs()\n");
        if (!tiargs)
            return true;
        bool err = false;

        // The arguments are not treated as part of a default argument,
        // because they are evaluated at compile time.
        const inCondition = sc.condition;
        sc = sc.push();
        sc.inDefaultArg = false;

        // https://issues.dlang.org/show_bug.cgi?id=24699
        sc.condition = inCondition;

        for (size_t j = 0; j < tiargs.length; j++)
        {
            RootObject o = (*tiargs)[j];
            Type ta = isType(o);
            Expression ea = isExpression(o);
            Dsymbol sa = isDsymbol(o);

            //printf("1: (*tiargs)[%d] = %p, s=%p, v=%p, ea=%p, ta=%p\n", j, o, isDsymbol(o), isTuple(o), ea, ta);
            if (ta)
            {
                //printf("type %s\n", ta.toChars());

                // It might really be an Expression or an Alias
                ta.resolve(loc, sc, ea, ta, sa, (flags & 1) != 0);
                if (ea)
                    goto Lexpr;
                if (sa)
                    goto Ldsym;
                if (ta is null)
                {
                    assert(global.errors);
                    ta = Type.terror;
                }

            Ltype:
                if (TypeTuple tt = ta.isTypeTuple())
                {
                    // Expand tuple
                    size_t dim = tt.arguments.length;
                    tiargs.remove(j);
                    if (dim)
                    {
                        tiargs.reserve(dim);
                        foreach (i, arg; *tt.arguments)
                        {
                            if (flags & 2 && (arg.storageClass & STC.parameter))
                                tiargs.insert(j + i, arg);
                            else
                                tiargs.insert(j + i, arg.type);
                        }
                    }
                    j--;
                    continue;
                }
                if (ta.ty == Terror)
                {
                    err = true;
                    continue;
                }
                (*tiargs)[j] = ta.merge2();
            }
            else if (ea)
            {
            Lexpr:
                //printf("+[%d] ea = %s %s\n", j, EXPtoString(ea.op).ptr, ea.toChars());
                if (flags & 1) // only used by __traits
                {
                    ea = ea.expressionSemantic(sc);

                    // must not interpret the args, excepting template parameters
                    if (!ea.isVarExp() || (ea.isVarExp().var.storage_class & STC.templateparameter))
                    {
                        ea = ea.optimize(WANTvalue);
                    }
                }
                else
                {
                    sc = sc.startCTFE();
                    ea = ea.expressionSemantic(sc);
                    sc = sc.endCTFE();

                    if (auto varExp = ea.isVarExp())
                    {
                        /* If the parameter is a function that is not called
                         * explicitly, i.e. `foo!func` as opposed to `foo!func()`,
                         * then it is a dsymbol, not the return value of `func()`
                         */
                        Declaration vd = varExp.var;
                        if (auto fd = vd.isFuncDeclaration())
                        {
                            sa = fd;
                            goto Ldsym;
                        }
                        /* Otherwise skip substituting a const var with
                         * its initializer. The problem is the initializer won't
                         * match with an 'alias' parameter. Instead, do the
                         * const substitution in TemplateValueParameter.matchArg().
                         */
                    }
                    else if (definitelyValueParameter(ea))
                    {
                        if (ea.checkValue()) // check void expression
                            ea = ErrorExp.get();
                        const olderrs = global.errors;
                        ea = ea.ctfeInterpret();
                        if (global.errors != olderrs)
                            ea = ErrorExp.get();
                    }
                }
                //printf("-[%d] ea = %s %s\n", j, EXPtoString(ea.op).ptr, ea.toChars());
                if (TupleExp te = ea.isTupleExp())
                {
                    // Expand tuple
                    size_t dim = te.exps.length;
                    tiargs.remove(j);
                    if (dim)
                    {
                        tiargs.reserve(dim);
                        foreach (i, exp; *te.exps)
                            tiargs.insert(j + i, exp);
                    }
                    j--;
                    continue;
                }
                if (ea.op == EXP.error)
                {
                    err = true;
                    continue;
                }
                (*tiargs)[j] = ea;

                if (ea.op == EXP.type)
                {
                    ta = ea.type;
                    goto Ltype;
                }
                if (ea.op == EXP.scope_)
                {
                    sa = ea.isScopeExp().sds;
                    goto Ldsym;
                }
                if (FuncExp fe = ea.isFuncExp())
                {
                    /* A function literal, that is passed to template and
                     * already semanticed as function pointer, never requires
                     * outer frame. So convert it to global function is valid.
                     */
                    if (fe.fd.tok == TOK.reserved && fe.type.ty == Tpointer)
                    {
                        // change to non-nested
                        fe.fd.tok = TOK.function_;
                        fe.fd.vthis = null;
                    }
                    else if (fe.td)
                    {
                        /* If template argument is a template lambda,
                         * get template declaration itself. */
                        //sa = fe.td;
                        //goto Ldsym;
                    }
                }
                if (ea.op == EXP.dotVariable && !(flags & 1))
                {
                    // translate expression to dsymbol.
                    sa = ea.isDotVarExp().var;
                    goto Ldsym;
                }
                if (auto te = ea.isTemplateExp())
                {
                    sa = te.td;
                    goto Ldsym;
                }
                if (ea.op == EXP.dotTemplateDeclaration && !(flags & 1))
                {
                    // translate expression to dsymbol.
                    sa = ea.isDotTemplateExp().td;
                    goto Ldsym;
                }
                if (auto de = ea.isDotExp())
                {
                    if (auto se = de.e2.isScopeExp())
                    {
                        sa = se.sds;
                        goto Ldsym;
                    }
                }
            }
            else if (sa)
            {
            Ldsym:
                //printf("dsym %s %s\n", sa.kind(), sa.toChars());
                if (sa.errors)
                {
                    err = true;
                    continue;
                }

                TupleDeclaration d = sa.toAlias().isTupleDeclaration();
                if (d)
                {
                    if (d is atd)
                    {
                        (*tiargs)[j] = d;
                        continue;
                    }
                    // Expand tuple
                    tiargs.remove(j);
                    tiargs.insert(j, d.objects);
                    j--;
                    continue;
                }
                if (FuncAliasDeclaration fa = sa.isFuncAliasDeclaration())
                {
                    FuncDeclaration f = fa.toAliasFunc();
                    if (!fa.hasOverloads && f.isUnique())
                    {
                        // Strip FuncAlias only when the aliased function
                        // does not have any overloads.
                        sa = f;
                    }
                }
                (*tiargs)[j] = sa;

                TemplateDeclaration td = sa.isTemplateDeclaration();
                if (td && td.semanticRun == PASS.initial && td.literal)
                {
                    td.dsymbolSemantic(sc);
                }
                FuncDeclaration fd = sa.isFuncDeclaration();
                if (fd)
                    functionSemantic(fd);
            }
            else if (isParameter(o))
            {
            }
            else
            {
                assert(0);
            }
            //printf("1: (*tiargs)[%d] = %p\n", j, (*tiargs)[j]);
        }
        sc.pop();
        version (none)
        {
            printf("-TemplateInstance.semanticTiargs()\n");
            for (size_t j = 0; j < tiargs.length; j++)
            {
                RootObject o = (*tiargs)[j];
                Type ta = isType(o);
                Expression ea = isExpression(o);
                Dsymbol sa = isDsymbol(o);
                Tuple va = isTuple(o);
                printf("\ttiargs[%d] = ta %p, ea %p, sa %p, va %p\n", j, ta, ea, sa, va);
            }
        }
        return !err;
    }

    /**********************************
     * Run semantic on the elements of tiargs.
     * Input:
     *      sc
     * Returns:
     *      false if one or more arguments have errors.
     * Note:
     *      This function is reentrant against error occurrence. If returns false,
     *      all elements of tiargs won't be modified.
     */
    extern (D) final bool semanticTiargs(Scope* sc)
    {
        //printf("+TemplateInstance.semanticTiargs() %s\n", toChars());
        if (semantictiargsdone)
            return true;
        if (semanticTiargs(loc, sc, tiargs, 0))
        {
            // cache the result iff semantic analysis succeeded entirely
            semantictiargsdone = 1;
            return true;
        }
        return false;
    }

    /**********************************
     * Find the TemplateDeclaration that matches this TemplateInstance best.
     *
     * Params:
     *   sc    = the scope this TemplateInstance resides in
     *   argumentList = function arguments in case of a template function
     *
     * Returns:
     *   `true` if a match was found, `false` otherwise
     */
    extern (D) final bool findBestMatch(Scope* sc, ArgumentList argumentList)
    {
        if (havetempdecl)
        {
            TemplateDeclaration tempdecl = this.tempdecl.isTemplateDeclaration();
            assert(tempdecl);
            assert(tempdecl._scope);
            // Deduce tdtypes
            tdtypes.setDim(tempdecl.parameters.length);
            if (!matchWithInstance(sc, tempdecl, this, tdtypes, argumentList, 2))
            {
                .error(loc, "%s `%s` incompatible arguments for template instantiation", kind, toPrettyChars);
                return false;
            }
            // TODO: Normalizing tiargs for https://issues.dlang.org/show_bug.cgi?id=7469 is necessary?
            return true;
        }

        static if (LOG)
        {
            printf("TemplateInstance.findBestMatch()\n");
        }

        const errs = global.errors;
        TemplateDeclaration td_last = null;
        Objects dedtypes;

        /* Since there can be multiple TemplateDeclaration's with the same
         * name, look for the best match.
         */
        auto tovers = tempdecl.isOverloadSet();
        foreach (size_t oi; 0 .. tovers ? tovers.a.length : 1)
        {
            TemplateDeclaration td_best;
            TemplateDeclaration td_ambig;
            MATCH m_best = MATCH.nomatch;

            Dsymbol dstart = tovers ? tovers.a[oi] : tempdecl;
            overloadApply(dstart, (Dsymbol s)
            {
                auto td = s.isTemplateDeclaration();
                if (!td)
                    return 0;
                if (td == td_best)   // skip duplicates
                    return 0;

                //printf("td = %s\n", td.toPrettyChars());
                // If more arguments than parameters,
                // then this is no match.
                if (td.parameters.length < tiargs.length)
                {
                    if (!td.isVariadic())
                        return 0;
                }

                dedtypes.setDim(td.parameters.length);
                dedtypes.zero();
                assert(td.semanticRun != PASS.initial);

                MATCH m = matchWithInstance(sc, td, this, dedtypes, argumentList, 0);
                //printf("matchWithInstance = %d\n", m);
                if (m == MATCH.nomatch) // no match at all
                    return 0;
                if (m < m_best) goto Ltd_best;
                if (m > m_best) goto Ltd;

                // Disambiguate by picking the most specialized TemplateDeclaration
                {
                MATCH c1 = leastAsSpecialized(sc, td, td_best, argumentList);
                MATCH c2 = leastAsSpecialized(sc, td_best, td, argumentList);
                //printf("c1 = %d, c2 = %d\n", c1, c2);
                if (c1 > c2) goto Ltd;
                if (c1 < c2) goto Ltd_best;
                }

                td_ambig = td;
                return 0;

            Ltd_best:
                // td_best is the best match so far
                td_ambig = null;
                return 0;

            Ltd:
                // td is the new best match
                td_ambig = null;
                td_best = td;
                m_best = m;
                tdtypes.setDim(dedtypes.length);
                memcpy(tdtypes.tdata(), dedtypes.tdata(), tdtypes.length * (void*).sizeof);
                return 0;
            });

            if (td_ambig)
            {
                .error(loc, "%s `%s.%s` matches more than one template declaration:",
                    td_best.kind(), td_best.parent.toPrettyChars(), td_best.ident.toChars());
                .errorSupplemental(td_best.loc, "`%s`\nand:", td_best.toChars());
                .errorSupplemental(td_ambig.loc, "`%s`", td_ambig.toChars());
                return false;
            }
            if (td_best)
            {
                if (!td_last)
                    td_last = td_best;
                else if (td_last != td_best)
                {
                    ScopeDsymbol.multiplyDefined(loc, td_last, td_best);
                    return false;
                }
            }
        }

        if (td_last)
        {
            /* https://issues.dlang.org/show_bug.cgi?id=7469
             * Normalize tiargs by using corresponding deduced
             * template value parameters and tuples for the correct mangling.
             *
             * By doing this before hasNestedArgs, CTFEable local variable will be
             * accepted as a value parameter. For example:
             *
             *  void foo() {
             *    struct S(int n) {}   // non-global template
             *    const int num = 1;   // CTFEable local variable
             *    S!num s;             // S!1 is instantiated, not S!num
             *  }
             */
            size_t dim = td_last.parameters.length - (td_last.isVariadic() ? 1 : 0);
            for (size_t i = 0; i < dim; i++)
            {
                if (tiargs.length <= i)
                    tiargs.push(tdtypes[i]);
                assert(i < tiargs.length);

                auto tvp = (*td_last.parameters)[i].isTemplateValueParameter();
                if (!tvp)
                    continue;
                assert(tdtypes[i]);
                // tdtypes[i] is already normalized to the required type in matchArg

                (*tiargs)[i] = tdtypes[i];
            }
            if (td_last.isVariadic() && tiargs.length == dim && tdtypes[dim])
            {
                Tuple va = isTuple(tdtypes[dim]);
                assert(va);
                tiargs.pushSlice(va.objects[]);
            }
        }
        else if (errors && inst)
        {
            // instantiation was failed with error reporting
            assert(global.errors);
            return false;
        }
        else
        {
            auto tdecl = tempdecl.isTemplateDeclaration();

            if (errs != global.errors)
                errorSupplemental(loc, "while looking for match for `%s`", toChars());
            else if (tdecl && !tdecl.overnext)
            {
                // Only one template, so we can give better error message
                const(char)* msg = "does not match template declaration";
                const(char)* tip;
                OutBuffer buf;
                HdrGenState hgs;
                hgs.skipConstraints = true;
                toCharsMaybeConstraints(tdecl, buf, hgs);
                const tmsg = buf.peekChars();
                const cmsg = tdecl.getConstraintEvalError(tip);
                if (cmsg)
                {
                    .error(loc, "%s `%s` %s `%s`\n%s", kind, toPrettyChars, msg, tmsg, cmsg);
                    if (tip)
                        .tip(tip);
                }
                else
                {
                    .error(loc, "%s `%s` %s `%s`", kind, toPrettyChars, msg, tmsg);

                    if (tdecl.parameters.length == tiargs.length)
                    {
                        // https://issues.dlang.org/show_bug.cgi?id=7352
                        // print additional information, e.g. `foo` is not a type
                        foreach (i, param; *tdecl.parameters)
                        {
                            MATCH match = param.matchArg(loc, sc, tiargs, i, tdecl.parameters, dedtypes, null);
                            auto arg = (*tiargs)[i];
                            auto sym = arg.isDsymbol;
                            auto exp = arg.isExpression;

                            if (exp)
                                exp = exp.optimize(WANTvalue);

                            if (match == MATCH.nomatch &&
                                ((sym && sym.isFuncDeclaration) ||
                                 (exp && exp.isVarExp)))
                            {
                                if (param.isTemplateTypeParameter)
                                    errorSupplemental(loc, "`%s` is not a type", arg.toChars);
                                else if (auto tvp = param.isTemplateValueParameter)
                                    errorSupplemental(loc, "`%s` is not of a value of type `%s`",
                                                      arg.toChars, tvp.valType.toChars);

                            }
                        }
                    }
                }
            }
            else
            {
                .error(loc, "%s `%s` does not match any template declaration", kind(), toPrettyChars());
                bool found;
                overloadApply(tempdecl, (s){
                    if (!found)
                        errorSupplemental(loc, "Candidates are:");
                    found = true;
                    errorSupplemental(s.loc, "%s", s.toChars());
                    return 0;
                });
            }
            return false;
        }

        /* The best match is td_last
         */
        tempdecl = td_last;

        static if (LOG)
        {
            printf("\tIt's a match with template declaration '%s'\n", tempdecl.toChars());
        }
        return (errs == global.errors);
    }

    /*****************************************
     * Determines if a TemplateInstance will need a nested
     * generation of the TemplateDeclaration.
     * Sets enclosing property if so, and returns != 0;
     */
    extern (D) final bool hasNestedArgs(Objects* args, bool isstatic)
    {
        int nested = 0;
        //printf("TemplateInstance.hasNestedArgs('%s')\n", tempdecl.ident.toChars());

        // arguments from parent instances are also accessible
        if (!enclosing)
        {
            if (TemplateInstance ti = tempdecl.toParent().isTemplateInstance())
                enclosing = ti.enclosing;
        }

        /* A nested instance happens when an argument references a local
         * symbol that is on the stack.
         */
        foreach (o; *args)
        {
            Expression ea = isExpression(o);
            Dsymbol sa = isDsymbol(o);
            Tuple va = isTuple(o);
            if (ea)
            {
                if (auto ve = ea.isVarExp())
                {
                    sa = ve.var;
                    goto Lsa;
                }
                if (auto te = ea.isThisExp())
                {
                    sa = te.var;
                    goto Lsa;
                }
                if (auto fe = ea.isFuncExp())
                {
                    if (fe.td)
                        sa = fe.td;
                    else
                        sa = fe.fd;
                    goto Lsa;
                }
                // Emulate Expression.toMangleBuffer call that had exist in TemplateInstance.genIdent.
                if (ea.op != EXP.int64 && ea.op != EXP.float64 && ea.op != EXP.complex80 && ea.op != EXP.null_ && ea.op != EXP.string_ && ea.op != EXP.arrayLiteral && ea.op != EXP.assocArrayLiteral && ea.op != EXP.structLiteral)
                {
                    if (!ea.type.isTypeError())
                        .error(ea.loc, "%s `%s` expression `%s` is not a valid template value argument", kind, toPrettyChars, ea.toChars());
                    errors = true;
                }
            }
            else if (sa)
            {
            Lsa:
                sa = sa.toAlias();
                TemplateDeclaration td = sa.isTemplateDeclaration();
                if (td)
                {
                    TemplateInstance ti = sa.toParent().isTemplateInstance();
                    if (ti && ti.enclosing)
                        sa = ti;
                }
                TemplateInstance ti = sa.isTemplateInstance();
                Declaration d = sa.isDeclaration();
                if ((td && td.literal) || (ti && ti.enclosing) || (d && !d.isDataseg() && !(d.storage_class & STC.manifest) && (!d.isFuncDeclaration() || d.isFuncDeclaration().isNested()) && !isTemplateMixin()))
                {
                    Dsymbol dparent = sa.toParent2();
                    if (!dparent || dparent.isModule)
                        goto L1;
                    else if (!enclosing)
                        enclosing = dparent;
                    else if (enclosing != dparent)
                    {
                        /* Select the more deeply nested of the two.
                         * Error if one is not nested inside the other.
                         */
                        for (Dsymbol p = enclosing; p; p = p.parent)
                        {
                            if (p == dparent)
                                goto L1; // enclosing is most nested
                        }
                        for (Dsymbol p = dparent; p; p = p.parent)
                        {
                            if (p == enclosing)
                            {
                                enclosing = dparent;
                                goto L1; // dparent is most nested
                            }
                        }
                        //https://issues.dlang.org/show_bug.cgi?id=17870
                        if (dparent.isClassDeclaration() && enclosing.isClassDeclaration())
                        {
                            auto pc = dparent.isClassDeclaration();
                            auto ec = enclosing.isClassDeclaration();
                            if (pc.isBaseOf(ec, null))
                                goto L1;
                            else if (ec.isBaseOf(pc, null))
                            {
                                enclosing = dparent;
                                goto L1;
                            }
                        }
                        .error(loc, "%s `%s` `%s` is nested in both `%s` and `%s`", kind, toPrettyChars, toChars(), enclosing.toChars(), dparent.toChars());
                        errors = true;
                    }
                L1:
                    //printf("\tnested inside %s as it references %s\n", enclosing.toChars(), sa.toChars());
                    nested |= 1;
                }
            }
            else if (va)
            {
                nested |= cast(int)hasNestedArgs(&va.objects, isstatic);
            }
        }
        //printf("-TemplateInstance.hasNestedArgs('%s') = %d\n", tempdecl.ident.toChars(), nested);
        return nested != 0;
    }

    /****************************************************
     * Declare parameters of template instance, initialize them with the
     * template instance arguments.
     */
    extern (D) final void declareParameters(Scope* sc)
    {
        TemplateDeclaration tempdecl = this.tempdecl.isTemplateDeclaration();
        assert(tempdecl);

        //printf("TemplateInstance.declareParameters()\n");
        foreach (i, o; tdtypes) // initializer for tp
        {
            TemplateParameter tp = (*tempdecl.parameters)[i];
            //printf("\ttdtypes[%d] = %p\n", i, o);
            declareParameter(tempdecl, sc, tp, o);
        }
    }

    /****************************************
     * This instance needs an identifier for name mangling purposes.
     * Create one by taking the template declaration name and adding
     * the type signature for it.
     */
    extern (D) final Identifier genIdent(Objects* args)
    {
        //printf("TemplateInstance.genIdent('%s')\n", tempdecl.ident.toChars());
        assert(args is tiargs);
        OutBuffer buf;
        mangleToBuffer(this, buf);
        //printf("\tgenIdent = %s\n", buf.peekChars());
        return Identifier.idPool(buf[]);
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/**************************************
 * IsExpression can evaluate the specified type speculatively, and even if
 * it instantiates any symbols, they are normally unnecessary for the
 * final executable.
 * However, if those symbols leak to the actual code, compiler should remark
 * them as non-speculative to generate their code and link to the final executable.
 */
void unSpeculative(Scope* sc, RootObject o)
{
    if (!o)
        return;

    if (Tuple tup = isTuple(o))
    {
        foreach (obj; tup.objects)
        {
            unSpeculative(sc, obj);
        }
        return;
    }

    Dsymbol s = getDsymbol(o);
    if (!s)
        return;

    if (Declaration d = s.isDeclaration())
    {
        if (VarDeclaration vd = d.isVarDeclaration())
            o = vd.type;
        else if (AliasDeclaration ad = d.isAliasDeclaration())
        {
            o = ad.getType();
            if (!o)
                o = ad.toAlias();
        }
        else
            o = d.toAlias();

        s = getDsymbol(o);
        if (!s)
            return;
    }

    if (TemplateInstance ti = s.isTemplateInstance())
    {
        // If the instance is already non-speculative,
        // or it is leaked to the speculative scope.
        if (ti.minst !is null || sc.minst is null)
            return;

        // Remark as non-speculative instance.
        ti.minst = sc.minst;
        if (!ti.tinst)
            ti.tinst = sc.tinst;

        unSpeculative(sc, ti.tempdecl);
    }

    if (TemplateInstance ti = s.isInstantiated())
        unSpeculative(sc, ti);
}

/**********************************
 * Return true if e could be valid only as a template value parameter.
 * Return false if it might be an alias or tuple.
 * (Note that even in this case, it could still turn out to be a value).
 */
bool definitelyValueParameter(Expression e) @safe
{
    // None of these can be value parameters
    if (e.op == EXP.tuple || e.op == EXP.scope_ ||
        e.op == EXP.type || e.op == EXP.dotType ||
        e.op == EXP.template_ || e.op == EXP.dotTemplateDeclaration ||
        e.op == EXP.function_ || e.op == EXP.error ||
        e.op == EXP.this_ || e.op == EXP.super_ ||
        e.op == EXP.dot)
        return false;

    if (e.op != EXP.dotVariable)
        return true;

    /* Template instantiations involving a DotVar expression are difficult.
     * In most cases, they should be treated as a value parameter, and interpreted.
     * But they might also just be a fully qualified name, which should be treated
     * as an alias.
     */

    // x.y.f cannot be a value
    FuncDeclaration f = e.isDotVarExp().var.isFuncDeclaration();
    if (f)
        return false;

    while (e.op == EXP.dotVariable)
    {
        e = e.isDotVarExp().e1;
    }
    // this.x.y and super.x.y couldn't possibly be valid values.
    if (e.op == EXP.this_ || e.op == EXP.super_)
        return false;

    // e.type.x could be an alias
    if (e.op == EXP.dotType)
        return false;

    // var.x.y is the only other possible form of alias
    if (e.op != EXP.variable)
        return true;

    VarDeclaration v = e.isVarExp().var.isVarDeclaration();
    // func.x.y is not an alias
    if (!v)
        return true;

    // https://issues.dlang.org/show_bug.cgi?id=16685
    // var.x.y where var is a constant available at compile time
    if (v.storage_class & STC.manifest)
        return true;

    // TODO: Should we force CTFE if it is a global constant?
    return false;
}

/***********************************************************
 * https://dlang.org/spec/template-mixin.html
 * Syntax:
 *    mixin MixinTemplateName [TemplateArguments] [Identifier];
 */
extern (C++) final class TemplateMixin : TemplateInstance
{
    TypeQualified tqual;

    extern (D) this(Loc loc, Identifier ident, TypeQualified tqual, Objects* tiargs)
    {
        super(loc,
              tqual.idents.length ? cast(Identifier)tqual.idents[tqual.idents.length - 1] : (cast(TypeIdentifier)tqual).ident,
              tiargs ? tiargs : new Objects());
        //printf("TemplateMixin(ident = '%s')\n", ident ? ident.toChars() : "");
        this.dsym = DSYM.templateMixin;
        this.ident = ident;
        this.tqual = tqual;
    }

    override TemplateInstance syntaxCopy(Dsymbol s)
    {
        auto tm = new TemplateMixin(loc, ident, tqual.syntaxCopy(), tiargs);
        return TemplateInstance.syntaxCopy(tm);
    }

    override const(char)* kind() const
    {
        return "mixin";
    }

    extern (D) bool findTempDecl(Scope* sc)
    {
        // Follow qualifications to find the TemplateDeclaration
        if (!tempdecl)
        {
            Expression e;
            Type t;
            Dsymbol s;
            tqual.resolve(loc, sc, e, t, s);
            if (!s)
            {
                .error(loc, "%s `%s` is not defined", kind, toPrettyChars);
                return false;
            }
            s = s.toAlias();
            tempdecl = s.isTemplateDeclaration();
            OverloadSet os = s.isOverloadSet();

            /* If an OverloadSet, look for a unique member that is a template declaration
             */
            if (os)
            {
                Dsymbol ds = null;
                foreach (i, sym; os.a)
                {
                    Dsymbol s2 = sym.isTemplateDeclaration();
                    if (s2)
                    {
                        if (ds)
                        {
                            tempdecl = os;
                            break;
                        }
                        ds = s2;
                    }
                }
            }
            if (!tempdecl)
            {
                .error(loc, "%s `%s` - `%s` is a %s, not a template", kind, toPrettyChars, s.toChars(), s.kind());
                return false;
            }
        }
        assert(tempdecl);

        // Look for forward references
        auto tovers = tempdecl.isOverloadSet();
        foreach (size_t oi; 0 .. tovers ? tovers.a.length : 1)
        {
            Dsymbol dstart = tovers ? tovers.a[oi] : tempdecl;
            int r = overloadApply(dstart, (Dsymbol s)
            {
                auto td = s.isTemplateDeclaration();
                if (!td)
                    return 0;

                if (td.semanticRun == PASS.initial)
                {
                    if (td._scope)
                        td.dsymbolSemantic(td._scope);
                    else
                    {
                        semanticRun = PASS.initial;
                        return 1;
                    }
                }
                return 0;
            });
            if (r)
                return false;
        }
        return true;
    }

    override void accept(Visitor v)
    {
        v.visit(this);
    }
}

/************************************
 * This struct is needed for TemplateInstance to be the key in an associative array.
 * Fixing https://issues.dlang.org/show_bug.cgi?id=15813 would make it unnecessary.
 */
struct TemplateInstanceBox
{
    TemplateInstance ti;

    this(TemplateInstance ti)
    {
        this.ti = ti;
        this.ti.toHash();
        assert(this.ti.hash);
    }

    size_t toHash() const @safe pure nothrow
    {
        assert(ti.hash);
        return ti.hash;
    }

    bool opEquals(ref const TemplateInstanceBox s) @trusted const
    {
        bool res = void;
        if (ti.inst && s.ti.inst)
        {
            /* This clause is only used when an instance with errors
             * is replaced with a correct instance.
             */
            res = ti is s.ti;
        }
        else
        {
            /* Used when a proposed instance is used to see if there's
             * an existing instance.
             */
            static if (__VERSION__ < 2099) // https://issues.dlang.org/show_bug.cgi?id=22717
                res = (cast()s.ti).equalsx(cast()ti);
            else
                res = (cast()ti).equalsx(cast()s.ti);
        }

        debug (FindExistingInstance) ++(res ? nHits : nCollisions);
        return res;
    }

    debug (FindExistingInstance)
    {
        __gshared uint nHits, nCollisions;

        shared static ~this()
        {
            printf("debug (FindExistingInstance) TemplateInstanceBox.equals hits: %u collisions: %u\n",
                   nHits, nCollisions);
        }
    }
}

/*******************************************
 * Match to a particular TemplateParameter.
 * Input:
 *      instLoc         location that the template is instantiated.
 *      tiargs[]        actual arguments to template instance
 *      i               i'th argument
 *      parameters[]    template parameters
 *      dedtypes[]      deduced arguments to template instance
 *      *psparam        set to symbol declared and initialized to dedtypes[i]
 */
MATCH matchArg(TemplateParameter tp, Loc instLoc, Scope* sc, Objects* tiargs, size_t i, TemplateParameters* parameters, ref Objects dedtypes, Declaration* psparam)
{
    MATCH matchArgNoMatch()
    {
        if (psparam)
            *psparam = null;
        return MATCH.nomatch;
    }

    MATCH matchArgParameter()
    {
        RootObject oarg;

        if (i < tiargs.length)
            oarg = (*tiargs)[i];
        else
        {
            // Get default argument instead
            oarg = tp.defaultArg(instLoc, sc);
            if (!oarg)
            {
                assert(i < dedtypes.length);
                // It might have already been deduced
                oarg = dedtypes[i];
                if (!oarg)
                    return matchArgNoMatch();
            }
        }
        return tp.matchArg(sc, oarg, i, parameters, dedtypes, psparam);
    }

    MATCH matchArgTuple(TemplateTupleParameter ttp)
    {
        /* The rest of the actual arguments (tiargs[]) form the match
         * for the variadic parameter.
         */
        assert(i + 1 == dedtypes.length); // must be the last one
        Tuple ovar;

        if (Tuple u = isTuple(dedtypes[i]))
        {
            // It has already been deduced
            ovar = u;
        }
        else if (i + 1 == tiargs.length && isTuple((*tiargs)[i]))
            ovar = isTuple((*tiargs)[i]);
        else
        {
            ovar = new Tuple();
            //printf("ovar = %p\n", ovar);
            if (i < tiargs.length)
            {
                //printf("i = %d, tiargs.length = %d\n", i, tiargs.length);
                ovar.objects.setDim(tiargs.length - i);
                foreach (j, ref obj; ovar.objects)
                    obj = (*tiargs)[i + j];
            }
        }
        return ttp.matchArg(sc, ovar, i, parameters, dedtypes, psparam);
    }

    if (auto ttp = tp.isTemplateTupleParameter())
        return matchArgTuple(ttp);

    return matchArgParameter();
}

MATCH matchArg(TemplateParameter tp, Scope* sc, RootObject oarg, size_t i, TemplateParameters* parameters, ref Objects dedtypes, Declaration* psparam)
{
    MATCH matchArgNoMatch()
    {
        //printf("\tm = %d\n", MATCH.nomatch);
        if (psparam)
            *psparam = null;
        return MATCH.nomatch;
    }

    MATCH matchArgType(TemplateTypeParameter ttp)
    {
        //printf("TemplateTypeParameter.matchArg('%s')\n", ttp.ident.toChars());
        MATCH m = MATCH.exact;
        Type ta = isType(oarg);
        if (!ta)
        {
            //printf("%s %p %p %p\n", oarg.toChars(), isExpression(oarg), isDsymbol(oarg), isTuple(oarg));
            return matchArgNoMatch();
        }
        //printf("ta is %s\n", ta.toChars());

        if (ttp.specType)
        {
            if (!ta || ta == TemplateTypeParameter.tdummy)
                return matchArgNoMatch();

            //printf("\tcalling deduceType(): ta is %s, specType is %s\n", ta.toChars(), ttp.specType.toChars());
            MATCH m2 = deduceType(ta, sc, ttp.specType, *parameters, dedtypes);
            if (m2 == MATCH.nomatch)
            {
                //printf("\tfailed deduceType\n");
                return matchArgNoMatch();
            }

            if (m2 < m)
                m = m2;
            if (dedtypes[i])
            {
                Type t = cast(Type)dedtypes[i];

                if (ttp.dependent && !t.equals(ta)) // https://issues.dlang.org/show_bug.cgi?id=14357
                    return matchArgNoMatch();

                /* This is a self-dependent parameter. For example:
                 *  template X(T : T*) {}
                 *  template X(T : S!T, alias S) {}
                 */
                //printf("t = %s ta = %s\n", t.toChars(), ta.toChars());
                ta = t;
            }
        }
        else
        {
            if (dedtypes[i])
            {
                // Must match already deduced type
                Type t = cast(Type)dedtypes[i];

                if (!t.equals(ta))
                {
                    //printf("t = %s ta = %s\n", t.toChars(), ta.toChars());
                    return matchArgNoMatch();
                }
            }
            else
            {
                // So that matches with specializations are better
                m = MATCH.convert;
            }
        }
        dedtypes[i] = ta;

        if (psparam)
            *psparam = new AliasDeclaration(ttp.loc, ttp.ident, ta);
        //printf("\tm = %d\n", m);
        return ttp.dependent ? MATCH.exact : m;
    }

    MATCH matchArgValue(TemplateValueParameter tvp)
    {
        //printf("TemplateValueParameter.matchArg('%s')\n", tvp.ident.toChars());
        MATCH m = MATCH.exact;

        Expression ei = isExpression(oarg);
        Type vt;

        if (!ei && oarg)
        {
            Dsymbol si = isDsymbol(oarg);
            FuncDeclaration f = si ? si.isFuncDeclaration() : null;
            if (!f || !f.fbody || f.needThis())
                return matchArgNoMatch();

            ei = new VarExp(tvp.loc, f);
            ei = ei.expressionSemantic(sc);

            /* If a function is really property-like, and then
             * it's CTFEable, ei will be a literal expression.
             */
            const olderrors = global.startGagging();
            ei = resolveProperties(sc, ei);
            ei = ei.ctfeInterpret();
            if (global.endGagging(olderrors) || ei.op == EXP.error)
                return matchArgNoMatch();

            /* https://issues.dlang.org/show_bug.cgi?id=14520
             * A property-like function can match to both
             * TemplateAlias and ValueParameter. But for template overloads,
             * it should always prefer alias parameter to be consistent
             * template match result.
             *
             *   template X(alias f) { enum X = 1; }
             *   template X(int val) { enum X = 2; }
             *   int f1() { return 0; }  // CTFEable
             *   int f2();               // body-less function is not CTFEable
             *   enum x1 = X!f1;    // should be 1
             *   enum x2 = X!f2;    // should be 1
             *
             * e.g. The x1 value must be same even if the f1 definition will be moved
             *      into di while stripping body code.
             */
            m = MATCH.convert;
        }

        if (ei && ei.op == EXP.variable)
        {
            // Resolve const variables that we had skipped earlier
            ei = ei.ctfeInterpret();
        }

        //printf("\tvalType: %s, ty = %d\n", tvp.valType.toChars(), tvp.valType.ty);
        vt = tvp.valType.typeSemantic(tvp.loc, sc);
        //printf("ei: %s, ei.type: %s\n", ei.toChars(), ei.type.toChars());
        //printf("vt = %s\n", vt.toChars());

        if (ei.type)
        {
            MATCH m2 = ei.implicitConvTo(vt);
            //printf("m: %d\n", m);
            if (m2 < m)
                m = m2;
            if (m == MATCH.nomatch)
                return matchArgNoMatch();
            ei = ei.implicitCastTo(sc, vt);
            ei = ei.ctfeInterpret();
        }

        if (tvp.specValue)
        {
            if (ei is null || (cast(void*)ei.type in TemplateValueParameter.edummies &&
                               TemplateValueParameter.edummies[cast(void*)ei.type] == ei))
                return matchArgNoMatch();

            Expression e = tvp.specValue;

            sc = sc.startCTFE();
            e = e.expressionSemantic(sc);
            e = resolveProperties(sc, e);
            sc = sc.endCTFE();
            e = e.implicitCastTo(sc, vt);
            e = e.ctfeInterpret();

            ei = ei.syntaxCopy();
            sc = sc.startCTFE();
            ei = ei.expressionSemantic(sc);
            sc = sc.endCTFE();
            ei = ei.implicitCastTo(sc, vt);
            ei = ei.ctfeInterpret();
            //printf("\tei: %s, %s\n", ei.toChars(), ei.type.toChars());
            //printf("\te : %s, %s\n", e.toChars(), e.type.toChars());
            if (!ei.equals(e))
                return matchArgNoMatch();
        }
        else
        {
            if (dedtypes[i])
            {
                // Must match already deduced value
                Expression e = cast(Expression)dedtypes[i];
                if (!ei || !ei.equals(e))
                    return matchArgNoMatch();
            }
        }
        dedtypes[i] = ei;

        if (psparam)
        {
            Initializer _init = new ExpInitializer(tvp.loc, ei);
            Declaration sparam = new VarDeclaration(tvp.loc, vt, tvp.ident, _init);
            sparam.storage_class = STC.manifest;
            *psparam = sparam;
        }
        return tvp.dependent ? MATCH.exact : m;
    }

    MATCH matchArgAlias(TemplateAliasParameter tap)
    {
        //printf("TemplateAliasParameter.matchArg('%s')\n", tap.ident.toChars());
        MATCH m = MATCH.exact;
        Type ta = isType(oarg);
        RootObject sa = ta && !ta.deco ? null : getDsymbol(oarg);
        Expression ea = isExpression(oarg);
        if (ea)
        {
            if (auto te = ea.isThisExp())
                sa = te.var;
            else if (auto se = ea.isSuperExp())
                sa = se.var;
            else if (auto se = ea.isScopeExp())
                sa = se.sds;
        }
        if (sa)
        {
            if ((cast(Dsymbol)sa).isAggregateDeclaration())
                m = MATCH.convert;

            /* specType means the alias must be a declaration with a type
             * that matches specType.
             */
            if (tap.specType)
            {
                tap.specType = typeSemantic(tap.specType, tap.loc, sc);
                Declaration d = (cast(Dsymbol)sa).isDeclaration();
                if (!d)
                    return matchArgNoMatch();
                if (!d.type.equals(tap.specType))
                    return matchArgNoMatch();
            }
        }
        else
        {
            sa = oarg;
            if (ea)
            {
                if (tap.specType)
                {
                    if (!ea.type.equals(tap.specType))
                        return matchArgNoMatch();
                }
            }
            else if (ta && ta.ty == Tinstance && !tap.specAlias)
            {
                /* Specialized parameter should be preferred
                 * match to the template type parameter.
                 *  template X(alias a) {}                      // a == this
                 *  template X(alias a : B!A, alias B, A...) {} // B!A => ta
                 */
            }
            else if (sa && sa == TemplateTypeParameter.tdummy)
            {
                /* https://issues.dlang.org/show_bug.cgi?id=2025
                 * Aggregate Types should preferentially
                 * match to the template type parameter.
                 *  template X(alias a) {}  // a == this
                 *  template X(T) {}        // T => sa
                 */
            }
            else if (ta && ta.ty != Tident)
            {
                /* Match any type that's not a TypeIdentifier to alias parameters,
                 * but prefer type parameter.
                 * template X(alias a) { }  // a == ta
                 *
                 * TypeIdentifiers are excluded because they might be not yet resolved aliases.
                 */
                m = MATCH.convert;
            }
            else
                return matchArgNoMatch();
        }

        if (tap.specAlias)
        {
            if (sa == TemplateAliasParameter.sdummy)
                return matchArgNoMatch();
            // check specialization if template arg is a symbol
            Dsymbol sx = isDsymbol(sa);
            if (sa != tap.specAlias && sx)
            {
                Type talias = isType(tap.specAlias);
                if (!talias)
                    return matchArgNoMatch();

                TemplateInstance ti = sx.isTemplateInstance();
                if (!ti && sx.parent)
                {
                    ti = sx.parent.isTemplateInstance();
                    if (ti && ti.name != sx.ident)
                        return matchArgNoMatch();
                }
                if (!ti)
                    return matchArgNoMatch();

                Type t = new TypeInstance(Loc.initial, ti);
                MATCH m2 = deduceType(t, sc, talias, *parameters, dedtypes);
                if (m2 == MATCH.nomatch)
                    return matchArgNoMatch();
            }
            // check specialization if template arg is a type
            else if (ta)
            {
                if (Type tspec = isType(tap.specAlias))
                {
                    MATCH m2 = ta.implicitConvTo(tspec);
                    if (m2 == MATCH.nomatch)
                        return matchArgNoMatch();
                }
                else
                {
                    error(tap.loc, "template parameter specialization for a type must be a type and not `%s`",
                        tap.specAlias.toChars());
                    return matchArgNoMatch();
                }
            }
        }
        else if (dedtypes[i])
        {
            // Must match already deduced symbol
            RootObject si = dedtypes[i];
            if (!sa || si != sa)
                return matchArgNoMatch();
        }
        dedtypes[i] = sa;

        if (psparam)
        {
            if (Dsymbol s = isDsymbol(sa))
            {
                *psparam = new AliasDeclaration(tap.loc, tap.ident, s);
            }
            else if (Type t = isType(sa))
            {
                *psparam = new AliasDeclaration(tap.loc, tap.ident, t);
            }
            else
            {
                assert(ea);

                // Declare manifest constant
                Initializer _init = new ExpInitializer(tap.loc, ea);
                auto v = new VarDeclaration(tap.loc, null, tap.ident, _init);
                v.storage_class = STC.manifest;
                v.dsymbolSemantic(sc);
                *psparam = v;
            }
        }
        return tap.dependent ? MATCH.exact : m;
    }

    MATCH matchArgTuple(TemplateTupleParameter ttp)
    {
        //printf("TemplateTupleParameter.matchArg('%s')\n", ttp.ident.toChars());
        Tuple ovar = isTuple(oarg);
        if (!ovar)
            return MATCH.nomatch;
        if (dedtypes[i])
        {
            Tuple tup = isTuple(dedtypes[i]);
            if (!tup)
                return MATCH.nomatch;
            if (!match(tup, ovar))
                return MATCH.nomatch;
        }
        dedtypes[i] = ovar;

        if (psparam)
            *psparam = new TupleDeclaration(ttp.loc, ttp.ident, &ovar.objects);
        return ttp.dependent ? MATCH.exact : MATCH.convert;
    }

    if (auto ttp = tp.isTemplateTypeParameter())
        return matchArgType(ttp);
    if (auto tvp = tp.isTemplateValueParameter())
        return matchArgValue(tvp);
    if (auto tap = tp.isTemplateAliasParameter())
        return matchArgAlias(tap);
    if (auto ttp = tp.isTemplateTupleParameter())
        return matchArgTuple(ttp);
    assert(0);
}


/***********************************************
 * Collect and print statistics on template instantiations.
 */
struct TemplateStats
{
    __gshared TemplateStats[const void*] stats;

    uint numInstantiations;     // number of instantiations of the template
    uint uniqueInstantiations;  // number of unique instantiations of the template

    TemplateInstances* allInstances;

    /*******************************
     * Add this instance
     * Params:
     *  td = template declaration
     *  ti = instance of td
     *  listInstances = keep track of instances of templates
     */
    static void incInstance(const TemplateDeclaration td,
                            const TemplateInstance ti,
                            bool listInstances)
    {
        void log(ref TemplateStats ts)
        {
            if (ts.allInstances is null)
                ts.allInstances = new TemplateInstances();
            if (listInstances)
                ts.allInstances.push(cast() ti);
        }

        // message(ti.loc, "incInstance %p %p", td, ti);
        if (!td)
            return;
        assert(ti);
        if (auto ts = cast(const void*) td in stats)
        {
            log(*ts);
            ++ts.numInstantiations;
        }
        else
        {
            stats[cast(const void*) td] = TemplateStats(1, 0);
            log(stats[cast(const void*) td]);
        }
    }

    /*******************************
     * Add this unique instance
     */
    static void incUnique(const TemplateDeclaration td,
                          const TemplateInstance ti)
    {
        // message(ti.loc, "incUnique %p %p", td, ti);
        if (!td)
            return;
        assert(ti);
        if (auto ts = cast(const void*) td in stats)
            ++ts.uniqueInstantiations;
        else
            stats[cast(const void*) td] = TemplateStats(0, 1);
    }
}

/********************************
 * Print informational statistics on template instantiations.
 * Params:
 *      listInstances = list instances of templates
 *      eSink = where the print is sent
 */
void printTemplateStats(bool listInstances, ErrorSink eSink)
{
    static struct TemplateDeclarationStats
    {
        TemplateDeclaration td;
        TemplateStats ts;
        static int compare(scope const TemplateDeclarationStats* a,
                           scope const TemplateDeclarationStats* b) @safe nothrow @nogc pure
        {
            auto diff = b.ts.uniqueInstantiations - a.ts.uniqueInstantiations;
            if (diff)
                return diff;

            return b.ts.numInstantiations - a.ts.numInstantiations;
        }
    }

    const stats_length = TemplateStats.stats.length;
    if (!stats_length)
        return;         // nothing to report

    Array!(TemplateDeclarationStats) sortedStats;
    sortedStats.reserve(stats_length);
    foreach (td_, ref ts; TemplateStats.stats)
    {
        sortedStats.push(TemplateDeclarationStats(cast(TemplateDeclaration) td_, ts));
    }

    sortedStats.sort!(TemplateDeclarationStats.compare);

    OutBuffer buf;
    foreach (const ref ss; sortedStats[])
    {
        buf.reset();
        HdrGenState hgs;
        hgs.skipConstraints = true;
        toCharsMaybeConstraints(ss.td, buf, hgs);
        const tchars = buf.peekChars();
        if (listInstances && ss.ts.allInstances)
        {
            eSink.message(ss.td.loc,
                    "vtemplate: %u (%u distinct) instantiation(s) of template `%s` found, they are:",
                    ss.ts.numInstantiations,
                    ss.ts.uniqueInstantiations,
                    tchars);
            foreach (const ti; (*ss.ts.allInstances)[])
            {
                if (ti.tinst)   // if has enclosing instance
                    eSink.message(ti.loc, "vtemplate: implicit instance `%s`", ti.toChars());
                else
                    eSink.message(ti.loc, "vtemplate: explicit instance `%s`", ti.toChars());
            }
        }
        else
        {
            eSink.message(ss.td.loc,
                    "vtemplate: %u (%u distinct) instantiation(s) of template `%s` found",
                    ss.ts.numInstantiations,
                    ss.ts.uniqueInstantiations,
                    tchars);
        }
    }
}

/// Pair of MATCHes
struct MATCHpair
{
    MATCH mta;  /// match template parameters by initial template arguments
    MATCH mfa;  /// match template parameters by inferred template arguments

    debug this(MATCH mta, MATCH mfa)
    {
        assert(MATCH.min <= mta && mta <= MATCH.max);
        assert(MATCH.min <= mfa && mfa <= MATCH.max);
        this.mta = mta;
        this.mfa = mfa;
    }
}

void write(ref OutBuffer buf, RootObject obj)
{
    if (obj)
    {
        if (auto e = isExpression(obj))
            buf.writestring(e.toErrMsg());
        else
            buf.writestring(obj.toChars());
    }
}
