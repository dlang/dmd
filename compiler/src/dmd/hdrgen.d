/**
 * Generate $(LINK2 https://dlang.org/dmd-windows.html#interface-files, D interface files).
 *
 * Also used to convert AST nodes to D code in general, e.g. for error messages or `printf` debugging.
 *
 * Copyright:   Copyright (C) 1999-2024 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/hdrgen.d, _hdrgen.d)
 * Documentation:  https://dlang.org/phobos/dmd_hdrgen.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/hdrgen.d
 */

module dmd.hdrgen;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import dmd.aggregate;
import dmd.aliasthis;
import dmd.arraytypes;
import dmd.astenums;
import dmd.attrib;
import dmd.cond;
import dmd.ctfeexpr;
import dmd.dclass;
import dmd.declaration;
import dmd.denum;
import dmd.dimport;
import dmd.dmodule;
import dmd.doc;
import dmd.dstruct;
import dmd.dsymbol;
import dmd.dtemplate;
import dmd.dversion;
import dmd.expression;
import dmd.func;
import dmd.id;
import dmd.identifier;
import dmd.init;
import dmd.mtype;
import dmd.nspace;
import dmd.optimize;
import dmd.parse;
import dmd.root.complex;
import dmd.root.ctfloat;
import dmd.common.outbuffer;
import dmd.rootobject;
import dmd.root.string;
import dmd.statement;
import dmd.staticassert;
import dmd.tokens;
import dmd.typesem;
import dmd.visitor;

/**
    Print the visibility of a symbol to a buffer.

    Params:
        buf = the buffer.
        vis = the visibility.
*/
void visibilityToBuffer(ref OutBuffer buf, Visibility vis)
{
    buf.writestring(visibilityToString(vis.kind));

    if (vis.kind == Visibility.Kind.package_ && vis.pkg)
    {
        buf.writeByte('(');
        buf.writestring(vis.pkg.toPrettyChars(true));
        buf.writeByte(')');
    }
}

/**
    Map a visibility to its kind as a string.

    Params:
        kind = the visibility kind to map.

    Returns: A string representing the visibility kind.
*/
string visibilityToString(Visibility.Kind kind) pure nothrow @nogc @safe
{
    return TableOfVisibilityStrings[kind];
}

/**
    Map a visibility to its kind as a zero terminated string.

    Params:
        kind = the visibility kind to map.

    Returns: A zero terminated string that represents a visibility kind.
 */
const(char)* visibilityToChars(Visibility.Kind kind) pure nothrow @nogc @trusted
{
    // Null terminated because we return a literal
    return TableOfVisibilityStrings[kind].ptr;
}

/**
    Map a linkage as a string.

    Params:
        linkage = the linkage to map.

    Returns: A string representing the linkage type.
*/
string linkageToString(LINK linkage) pure nothrow @nogc @safe
{
    return TableOfLinkageStrings[linkage];
}

/**
    Map a linkage as a zero terminated string.

    Params:
        linkage = the linkage to map.

    Returns: A zero terminated string representing the linkage type.
 */
const(char)* linkageToChars(LINK linkage) pure nothrow @nogc @trusted
{
    return TableOfLinkageStrings[linkage].ptr;
}

/**
Convert an expression type to string.

Params:
    op = The expression type.

Returns: The string representation of an expression type.
*/
string expressionTypeToString(EXP op)
{
    return TableOfExpressionTypeStrings[op];
}

/**
Find the first active storage class, remove it and return its string representation.

Params:
    stc = A set of storage classes to look in and mutate.

Returns: The string representation of the first storage class or null if none are active.
*/
string storageClassToString(ref StorageClass stc) @safe
{
    if (stc > 0)
    {
        foreach (immutable ref entry; TableOfStorageClassStrings)
        {
            const StorageClass tbl = entry.stc;
            assert(tbl & STC.visibleStorageClasses);

            if (stc & tbl)
            {
                stc &= ~tbl;
                return entry.id;
            }
        }
    }

    return null;
}

/**
Write storage classes to a buffer.

Takes into account scope and return ordering.

Params:
    buf = The buffer to write into.
    stc = The storage classes.

Returns:
*/
bool storageClassToBuffer(ref OutBuffer buf, StorageClass stc) @safe
{
    //printf("stc: %llx\n", stc);
    bool result = false;

    if (stc & STC.scopeinferred)
    {
        stc &= ~(STC.scope_ | STC.scopeinferred);
    }
    if (stc & STC.returninferred)
    {
        stc &= ~(STC.return_ | STC.returninferred);
    }

    // Put scope ref return into a standard order
    string rrs;
    const isout = (stc & STC.out_) != 0;
    //printf("bsr = %d %llx\n", buildScopeRef(stc), stc);

    final switch (buildScopeRef(stc))
    {
    case ScopeRef.None, ScopeRef.Scope, ScopeRef.Ref, ScopeRef.Return:
        break;

    case ScopeRef.ReturnScope:
        rrs = "return scope";
        goto L1;
    case ScopeRef.ReturnRef:
        rrs = isout ? "return out" : "return ref";
        goto L1;
    case ScopeRef.RefScope:
        rrs = isout ? "out scope" : "ref scope";
        goto L1;
    case ScopeRef.ReturnRef_Scope:
        rrs = isout ? "return out scope" : "return ref scope";
        goto L1;
    case ScopeRef.Ref_ReturnScope:
        rrs = isout ? "out return scope" : "ref return scope";

    L1:
        stc &= ~(STC.out_ | STC.scope_ | STC.ref_ | STC.return_);

        buf.writestring(rrs);
        result = true;
        break;
    }

    string storageClassText;
    while ((storageClassText = storageClassToString(stc)) !is null)
    {
        if (result)
            buf.writeByte(' ');

        buf.writestring(storageClassText);
        result = true;
    }

    return result;
}

/**
Formats `value` as a literal of type `type` into `buf`.

 Params:
   type     = literal type (e.g. Tfloat)
   value    = value to print
   buf      = target buffer
   allowHex = whether hex floating point literals may be used
              for greater accuracy
*/
void floatToBuffer(Type type, const real_t value, ref OutBuffer buf, const bool allowHex)
{
    // sizeof(value)*3 is because each byte of mantissa is max
    //  of 256 (3 characters). The string will be "-M.MMMMe-4932".
    //  (ie, 8 chars more than mantissa). Plus one for trailing \0.
    // Plus one for rounding.
    const(size_t) BUFFER_LEN = value.sizeof * 3 + 8 + 1 + 1;
    char[BUFFER_LEN] buffer = void;

    CTFloat.sprint(buffer.ptr, BUFFER_LEN, 'g', value);
    assert(strlen(buffer.ptr) < BUFFER_LEN);

    if (allowHex)
    {
        bool isOutOfRange;
        real_t r = CTFloat.parse(buffer.ptr, isOutOfRange);
        //assert(!isOutOfRange); // test/compilable/test22725.c asserts here
        if (r != value) // if exact duplication
            CTFloat.sprint(buffer.ptr, BUFFER_LEN, 'a', value);
    }

    buf.writestring(buffer.ptr);
    if (buffer.ptr[strlen(buffer.ptr) - 1] == '.')
        buf.remove(buf.length() - 1, 1);

    if (type)
    {
        Type t = type.toBasetype();

        switch (t.ty)
        {
        case Tfloat32, Timaginary32, Tcomplex32:
            buf.writeByte('F');
            break;
        case Tfloat80, Timaginary80, Tcomplex80:
            buf.writeByte('L');
            break;
        default:
            break;
        }

        if (t.isimaginary())
            buf.writeByte('i');
    }
}

/**
    Turn an AST node into a string suitable for printf.
    Leaks memory.

    Params:
       node = AST node to convert
    Returns: 0-terminated string
*/
const(char)* toChars(const Statement node)
{
    HdrGenState hgs;
    OutBuffer buf;

    hgs.toCBuffer(node, buf);

    return buf.extractChars();
}

/// Ditto
const(char)* toChars(const Expression node)
{
    HdrGenState hgs;
    OutBuffer buf;

    hgs.toCBuffer(node, buf);

    return buf.extractChars();
}

/// Ditto
const(char)* toChars(const Initializer node)
{
    HdrGenState hgs;
    OutBuffer buf;

    hgs.toCBuffer(node, buf);

    return buf.extractChars();
}

/// Ditto
const(char)* toChars(const Type node)
{

    HdrGenState hgs;
    hgs.fullQual = (node.ty == Tclass && !node.mod);

    OutBuffer buf;
    hgs.toCBuffer(node, buf, null);

    return buf.extractChars();
}

/**
    Turn an AST node into a string suitable.
    Leaks memory.

    Params:
       node = AST node to convert
    Returns: A string.
*/
const(char)[] toString(const Initializer node)
{
    OutBuffer buf;
    HdrGenState hgs;
    hgs.toCBuffer(node, buf);
    return buf.extractSlice();
}

/**
    Write a template instance, template arguments out to buffer.

    Params:
        ti           = The template instance which contains template arguments.
        buf          = The buffer to write into.
        qualifyTypes = Should type names be fully qualified?
*/
void toCBufferInstance(const TemplateInstance ti, ref OutBuffer buf, bool qualifyTypes = false)
{
    HdrGenState hgs;
    hgs.fullQual = qualifyTypes;

    buf.writestring(ti.name.toChars());
    hgs.tiargsToBuffer(cast() ti, buf);
}

/**
    Dumps the full contents of module `m` to `buf`.
    Params:
        buf = buffer to write to.
        vcg_ast = write out codegen ast
        m = module to visit all members of.
*/
void moduleToBuffer(ref OutBuffer buf, bool vcg_ast, Module m)
{
    HdrGenState hgs;
    hgs.fullDump = true;
    hgs.vcg_ast = vcg_ast;
    hgs.toCBuffer(m, buf);
}

/**
    Genearate the contents of a D header file.

    Params:
        m            = The module to generate for.
        doFuncBodies = Will it include function bodies?
        buf          = The output buffer.
*/
void genhdrfile(Module m, bool doFuncBodies, ref OutBuffer buf)
{
    buf.doindent = 1;
    buf.printf("// D import file generated from '%s'", m.srcfile.toChars());
    buf.writenl();
    HdrGenState hgs;
    hgs.hdrgen = true;
    hgs.importcHdr = (m.filetype == FileType.c);
    hgs.doFuncBodies = doFuncBodies;
    hgs.toCBuffer(m, buf);
}

/**
    Pretty print function parameters.

    Params:
        pl = parameter list to print

    Returns: Null-terminated string representing parameters.
 */
const(char)* parametersTypeToChars(ParameterList pl)
{
    OutBuffer buf;
    HdrGenState hgs;
    hgs.parametersToBuffer(pl, buf);
    return buf.extractChars();
}

/**
    Write out argument types to buffer.

    Params:
        buf       = The buffer to write into.
        arguments = the expressions to acquire the types of from.
*/
void argExpTypesToCBuffer(ref OutBuffer buf, Expressions* arguments)
{
    if (!arguments || !arguments.length)
        return;

    HdrGenState hgs;

    foreach (i, arg; *arguments)
    {
        if (i)
            buf.writestring(", ");
        hgs.typeToBuffer(arg.type, null, buf);
    }
}

/**
    Write out an array of objects to buffer.

    Params:
        buf     = The buffer to write into.
        objects = the objects to write.
*/
void arrayObjectsToBuffer(ref OutBuffer buf, Objects* objects)
{
    if (!objects || !objects.length)
        return;

    HdrGenState hgs;

    foreach (i, o; *objects)
    {
        if (i)
            buf.writestring(", ");

        hgs.objectToBuffer(o, buf);
    }
}

/**
    Pretty print function parameter.

    Params:
        parameter = parameter to print.
        tf        = TypeFunction which holds parameter.
        fullQual  = whether to fully qualify types.

    Returns: Null-terminated string representing parameters.
*/
const(char)* parameterToChars(Parameter parameter, TypeFunction tf, bool fullQual)
{
    OutBuffer buf;
    HdrGenState hgs;
    hgs.fullQual = fullQual;

    hgs.parameterToBuffer(parameter, buf);

    if (tf.parameterList.varargs == VarArg.typesafe
            && parameter == tf.parameterList[tf.parameterList.parameters.length - 1])
    {
        buf.writestring("...");
    }

    return buf.extractChars();
}

struct HdrGenState
{
    bool hdrgen; /// true if generating header file
    bool ddoc; /// true if generating Ddoc file
    bool fullDump; /// true if generating a full AST dump file
    bool importcHdr; /// true if generating a .di file from an ImportC file
    bool doFuncBodies; /// include function bodies in output
    bool vcg_ast; /// write out codegen-ast
    bool skipConstraints; // skip constraints when doing templates
    bool showOneMember = true;

    bool fullQual; /// fully qualify types when printing
    int tpltMember;
    int autoMember;
    int forStmtInit;
    int insideFuncBody;
    int insideAggregate;

    bool declstring; // set while declaring alias for string,wstring or dstring
    EnumDeclaration inEnumDecl;

    /**
        Emit a function signature a buffer, using correct identifier, attributes and template arguments.

        Params:
            tf    = A function that has semantic information attached to it.
            buf   = The buffer to write into.
            ident = The function's identifier.
            td    = The template declaration.
    */
    void functionSignatureToBuffer(TypeFunction tf, ref OutBuffer buf,
            const Identifier ident, TemplateDeclaration td)
    {
        if (tf.inuse)
        {
            tf.inuse = 2; // flag error to caller
            return;
        }

        tf.inuse++;
        scope (exit)
            tf.inuse--;

        {
            // emit prefix attributes/linkage

            if (tf.linkage > LINK.d && this.ddoc != 1 && !this.hdrgen)
            {
                linkageToBuffer(buf, tf.linkage);
                buf.writeByte(' ');
            }

            void prefixWriteAttribute(string str)
            {
                if (str == "ref")
                {
                    if (ident == Id.ctor)
                        return;
                }
                else if (str != "@property")
                    return;

                buf.writestring(str);
                buf.writeByte(' ');
            }

            tf.attributesApply(&prefixWriteAttribute);
        }

        {
            // emit the return type

            if (ident && ident.toHChars2() != ident.toChars())
            {
                // Don't print return type for ctor, dtor, unittest, etc
            }
            else if (tf.next)
            {
                typeToBuffer(tf.next, null, buf);
                if (ident)
                    buf.writeByte(' ');
            }
            else if (this.ddoc)
            {
                buf.writestring("auto ");
            }
        }

        if (ident)
            buf.writestring(ident.toHChars2());

        {
            // emit the parameters

            // template parameters
            if (td)
            {
                buf.writeByte('(');
                foreach (i, p; *td.origParameters)
                {
                    if (i)
                        buf.writestring(", ");

                    toCBuffer(p, buf);
                }
                buf.writeByte(')');
            }

            if (ident !is Id.postblit)
                parametersToBuffer(tf.parameterList, buf);
        }

        {
            // Postfix storage classes & attributes

            if (tf.mod)
            {
                buf.writeByte(' ');
                MODtoBuffer(buf, tf.mod);
            }

            void postfixWriteAttribute(string str)
            {
                if (str != "ref" && str != "@property")
                {
                    buf.writeByte(' ');
                    buf.writestring(str);
                }
            }

            tf.attributesApply(&postfixWriteAttribute);
        }
    }

    /**
        Emit a function signature a buffer, using correct identifier, attributes with knowledge of if it is static.

        Params:
            tf          = A function that has semantic information attached to it.
            buf         = The buffer to write into.
            ident       = The function's identifier.
            isStatic    = Is the function static?
    */
    void functionSignatureToBufferAsPostfix(TypeFunction t, ref OutBuffer buf,
            const char[] ident, bool isStatic)
    {
        if (t.inuse)
        {
            t.inuse = 2; // flag error to caller
            return;
        }

        t.inuse++;
        scope (exit)
            t.inuse--;

        if (t.linkage > LINK.d && this.ddoc != 1 && !this.hdrgen)
        {
            linkageToBuffer(buf, t.linkage);
            buf.writeByte(' ');
        }

        if (t.linkage == LINK.objc && isStatic)
            buf.write("static ");

        {
            // emit the return type

            if (t.next)
            {
                typeToBuffer(t.next, null, buf);
                if (ident)
                    buf.writeByte(' ');
            }
            else if (this.ddoc)
                buf.writestring("auto ");
        }

        if (ident)
            buf.writestring(ident);

        parametersToBuffer(t.parameterList, buf);

        {
            // Use postfix style for attributes
            if (t.mod)
            {
                buf.writeByte(' ');
                MODtoBuffer(buf, t.mod);
            }

            void dg(string str)
            {
                buf.writeByte(' ');
                buf.writestring(str);
            }

            t.attributesApply(&dg);
        }
    }

    void toCBuffer(const TemplateParameter tp, ref OutBuffer buf)
    {
        scope v = new TemplateParameterPrettyPrintVisitor;
        v.buf = &buf;
        v.hgs = &this;

        (cast() tp).accept(v);
    }

    void toCBuffer(const Type t, ref OutBuffer buf, const Identifier ident)
    {
        typeToBuffer(cast() t, ident, buf);
    }

    void toCBuffer(const Expression e, ref OutBuffer buf)
    {
        expressionPrettyPrint(cast() e, buf);
    }

    void toCBuffer(Dsymbol s, ref OutBuffer buf)
    {
        scope v = new DsymbolPrettyPrintVisitor();
        v.hgs = &this;
        v.buf = &buf;

        /+if (s.getModule !is null)
            v.doTrace = s.getModule.ident.toString == "builder_utf8"
                || s.getModule.ident.toString == "testhdrgen";+/
        s.accept(v);
    }

    // Note: this function is not actually `const`, because iterating the
    // function parameter list may run dsymbolsemantic on enum types
    void toCharsMaybeConstraints(const TemplateDeclaration td, ref OutBuffer buf)
    {
        buf.writestring(td.ident == Id.ctor ? "this" : td.ident.toString());
        buf.writeByte('(');

        foreach (i, const tp; *td.parameters)
        {
            if (i)
                buf.writestring(", ");
            toCBuffer(tp, buf);
        }
        buf.writeByte(')');

        if (this.showOneMember && td.onemember)
        {
            if (const fd = td.onemember.isFuncDeclaration())
            {
                if (TypeFunction tf = cast(TypeFunction) fd.type.isTypeFunction())
                {
                    // !! Casted away const
                    buf.writestring(parametersTypeToChars(tf.parameterList));

                    if (tf.mod)
                    {
                        buf.writeByte(' ');
                        buf.MODtoBuffer(tf.mod);
                    }
                }
            }
        }

        if (!this.skipConstraints && td.constraint)
        {
            buf.writestring(" if (");
            toCBuffer(td.constraint, buf);
            buf.writeByte(')');
        }
    }

    /**
        Dumps the full contents of module `m` to `buf`.

        Params:
            buf = buffer to write to.
            m = module to visit all members of.
    */
    void moduleToBuffer2(Module m, ref OutBuffer buf)
    {
        if (m.md)
        {
            if (m.userAttribDecl)
            {
                buf.writestring("@(");
                argsToBuffer(m.userAttribDecl.atts, buf);
                buf.writeByte(')');
                buf.writenl();
            }
            if (m.md.isdeprecated)
            {
                if (m.md.msg)
                {
                    buf.writestring("deprecated(");
                    expressionPrettyPrint(m.md.msg, buf);
                    buf.writestring(") ");
                }
                else
                    buf.writestring("deprecated ");
            }
            buf.writestring("module ");
            buf.writestring(m.md.toChars());
            buf.writeByte(';');
            buf.writenl();
        }

        foreach (s; *m.members)
        {
            toCBuffer(s, buf);
        }
    }

private:

    int childCountOfModule;

    // not used outside this module
    void toCBuffer(const Initializer iz, ref OutBuffer buf)
    {
        initializerToBuffer(cast() iz, buf);
    }

    // not used outside this module
    void toCBuffer(const Statement s, ref OutBuffer buf)
    {
        statementToBuffer(cast() s, buf);
    }

    void typeToBuffer(Type t, const Identifier ident, ref OutBuffer buf, ubyte modMask = 0)
    {
        if (auto tf = t.isTypeFunction())
        {
            functionSignatureToBuffer(tf, buf, ident, null);
            return;
        }

        visitWithMask(t, modMask, buf);

        if (ident)
        {
            buf.writeByte(' ');
            buf.writestring(ident.toString());
        }
    }

    void visitWithMask(Type t, ubyte modMask, ref OutBuffer buf)
    {
        // Tuples and functions don't use the type constructor syntax
        if (modMask == t.mod || t.ty == Tfunction || t.ty == Ttuple)
        {
            typeToBufferx(t, buf);
        }
        else
        {
            ubyte m = t.mod & ~(t.mod & modMask);
            if (m & MODFlags.shared_)
            {
                MODtoBuffer(buf, MODFlags.shared_);
                buf.writeByte('(');
            }
            if (m & MODFlags.wild)
            {
                MODtoBuffer(buf, MODFlags.wild);
                buf.writeByte('(');
            }
            if (m & (MODFlags.const_ | MODFlags.immutable_))
            {
                MODtoBuffer(buf, m & (MODFlags.const_ | MODFlags.immutable_));
                buf.writeByte('(');
            }

            typeToBufferx(t, buf);

            if (m & (MODFlags.const_ | MODFlags.immutable_))
                buf.writeByte(')');
            if (m & MODFlags.wild)
                buf.writeByte(')');
            if (m & MODFlags.shared_)
                buf.writeByte(')');
        }
    }

    void parametersToBuffer(ParameterList pl, ref OutBuffer buf)
    {
        buf.writeByte('(');

        foreach (i; 0 .. pl.length)
        {
            if (i)
                buf.writestring(", ");

            parameterToBuffer(pl[i], buf);
        }

        final switch (pl.varargs)
        {
        case VarArg.none, VarArg.KRvariadic:
            break;

        case VarArg.variadic:
            if (pl.length)
                buf.writestring(", ");

            if (storageClassToBuffer(buf, pl.stc))
                buf.writeByte(' ');

            goto case VarArg.typesafe;

        case VarArg.typesafe:
            buf.writestring("...");
            break;
        }

        buf.writeByte(')');
    }

    void parameterToBuffer(Parameter p, ref OutBuffer buf)
    {
        if (p.userAttribDecl)
        {
            buf.writeByte('@');

            bool isAnonymous = p.userAttribDecl.atts.length > 0
                && !(*p.userAttribDecl.atts)[0].isCallExp();
            if (isAnonymous)
                buf.writeByte('(');

            argsToBuffer(p.userAttribDecl.atts, buf);

            if (isAnonymous)
                buf.writeByte(')');
            buf.writeByte(' ');
        }

        if (p.storageClass & STC.auto_)
            buf.writestring("auto ");

        StorageClass stc = p.storageClass;
        if (p.storageClass & STC.in_)
        {
            buf.writestring("in ");
            if ((p.storageClass & (STC.constscoperef | STC.ref_)) == (STC.constscoperef | STC.ref_))
                stc &= ~STC.ref_;
        }
        else if (p.storageClass & STC.lazy_)
            buf.writestring("lazy ");
        else if (p.storageClass & STC.alias_)
            buf.writestring("alias ");

        if (p.type && p.type.mod & MODFlags.shared_)
            stc &= ~STC.shared_;

        if (storageClassToBuffer(buf,
                stc & (
                STC.const_ | STC.immutable_ | STC.wild | STC.shared_ | STC.return_
                | STC.returninferred | STC.scope_ | STC.scopeinferred | STC.out_
                | STC.ref_ | STC.returnScope)))
            buf.writeByte(' ');

        const(char)[] s;
        if (p.storageClass & STC.alias_)
        {
            if (p.ident)
                buf.writestring(p.ident.toString());
        }
        else if (p.type.isTypeIdentifier() && (s = p.type.isTypeIdentifier()
                .ident.toString()).length > 3 && s[0 .. 3] == "__T")
        {
            // print parameter name, instead of undetermined type parameter
            buf.writestring(p.ident.toString());
        }
        else
        {
            typeToBuffer(p.type, p.ident, buf, (stc & STC.in_) ? MODFlags.const_ : 0);
        }

        if (p.defaultArg)
        {
            buf.writestring(" = ");
            expToBuffer(p.defaultArg, PREC.assign, buf);
        }
    }

    /*
        Write expression out to buf, but wrap it
        in ( ) if its precedence is less than pr.
    */
    void expToBuffer(Expression e, PREC pr, ref OutBuffer buf)
    {
        debug
        {
            if (precedence[e.op] == PREC.zero)
                printf("precedence not defined for token '%s'\n", expressionTypeToString(e.op).ptr);
        }

        if (e.op == 0xFF)
        {
            buf.writestring("<FF>");
            return;
        }

        assert(precedence[e.op] != PREC.zero);
        assert(pr != PREC.zero);

        // Despite precedence, we don't allow a<b<c expressions.
        // They must be parenthesized.

        if (precedence[e.op] < pr || (pr == PREC.rel && precedence[e.op] == pr)
                || (pr >= PREC.or && pr <= PREC.and && precedence[e.op] == PREC.rel))
        {
            buf.writeByte('(');
            expressionPrettyPrint(e, buf);
            buf.writeByte(')');
        }
        else
        {
            expressionPrettyPrint(e, buf);
        }
    }

    /**
     Write out argument list to buf.

     Params:
        expressions = argument list
        buf = buffer to write to
        hgs = context
        basis = replace `null`s in argument list with this expression (for sparse array literals)
        names = if non-null, use these as the names for the arguments
     */
    void argsToBuffer(Expressions* expressions, ref OutBuffer buf,
            Expression basis = null, Identifiers* names = null)
    {
        if (!expressions || !expressions.length)
            return;

        version (all)
        {
            foreach (i, el; *expressions)
            {
                if (i)
                    buf.writestring(", ");

                if (names && i < names.length && (*names)[i])
                {
                    buf.writestring((*names)[i].toString());
                    buf.writestring(": ");
                }

                if (!el)
                    el = basis;

                if (el)
                    expToBuffer(el, PREC.assign, buf);
            }
        }
        else
        {
            // Sparse style formatting, for debug use only
            //      [0..length: basis, 1: e1, 5: e5]

            if (basis)
            {
                buf.writestring("0..");
                buf.print(expressions.length);
                buf.writestring(": ");
                expToBuffer(basis, PREC.assign, buf);
            }

            foreach (i, el; *expressions)
            {
                if (el)
                {
                    if (basis)
                    {
                        buf.writestring(", ");
                        buf.print(i);
                        buf.writestring(": ");
                    }
                    else if (i)
                        buf.writestring(", ");
                    expToBuffer(el, PREC.assign, buf);
                }
            }
        }
    }

    /**
        Print an expression to buffer.

        Params:
            e = The expression.
            buf = the output buffer.
    */
    void expressionPrettyPrint(Expression e, ref OutBuffer buf)
    {
        void visitInteger(IntegerExp e)
        {
            const ulong v = e.toInteger();
            if (e.type)
            {
                Type t = e.type;
            L1:
                switch (t.ty)
                {
                case Tenum:
                    TypeEnum te = cast(TypeEnum) t;
                    auto sym = te.sym;
                    if (sym && sym.members && (!this.inEnumDecl || this.inEnumDecl != sym))
                    {
                        foreach (em; *sym.members)
                        {
                            if ((cast(EnumMember) em).value.toInteger == v)
                            {
                                const id = em.ident.toString();
                                buf.printf("%s.%.*s", sym.toChars(), cast(int) id.length, id.ptr);
                                return;
                            }
                        }
                    }

                    buf.printf("cast(%s)", te.sym.toChars());
                    t = te.sym.memtype;
                    goto L1;
                case Tchar, Twchar, Tdchar:
                    {
                        const o = buf.length;
                        writeSingleCharLiteral(buf, cast(dchar) v);

                        if (this.ddoc)
                            escapeDdocString(buf, o);
                        break;
                    }
                case Tint8:
                    buf.writestring("cast(byte)");
                    goto L2;
                case Tint16:
                    buf.writestring("cast(short)");
                    goto L2;
                case Tint32:
                L2:
                    buf.printf("%d", cast(int) v);
                    break;
                case Tuns8:
                    buf.writestring("cast(ubyte)");
                    goto case Tuns32;
                case Tuns16:
                    buf.writestring("cast(ushort)");
                    goto case Tuns32;
                case Tuns32:
                    buf.printf("%uu", cast(uint) v);
                    break;
                case Tint64:
                    if (v == long.min)
                    {
                        // https://issues.dlang.org/show_bug.cgi?id=23173
                        // This is a special case because - is not part of the
                        // integer literal and 9223372036854775808L overflows a long
                        buf.writestring("cast(long)-9223372036854775808");
                    }
                    else
                    {
                        buf.printf("%lldL", v);
                    }
                    break;
                case Tuns64:
                    buf.printf("%lluLU", v);
                    break;
                case Tbool:
                    buf.writestring(v ? "true" : "false");
                    break;
                case Tpointer:
                    buf.writestring("cast(");

                    // Should re-examine need for new hgs
                    // We do a copy of our state, so that input context and childCountOfModule applies from here on out.
                    HdrGenState hgs2 = this;
                    hgs2.fullQual = (t.ty == Tclass && !t.mod);
                    hgs2.toCBuffer(t, buf, null);

                    buf.writestring(")cast(size_t)");
                    goto case Tuns64;

                case Tvoid:
                    buf.writestring("cast(void)0");
                    break;

                default:
                    /* This can happen if errors, such as
                     * the type is painted on like in fromConstInitializer().
                     * Just ignore
                     */
                    break;
                }
            }
            else if (v & 0x8000000000000000L)
                buf.printf("0x%llx", v);
            else
                buf.print(v);
        }

        void floatToBuffer(Type type, real_t value)
        {
            .floatToBuffer(type, value, buf, this.hdrgen);
        }

        void visitReal(RealExp e)
        {
            floatToBuffer(e.type, e.value);
        }

        void visitComplex(ComplexExp e)
        {
            /* Print as:
             *  (re+imi)
             */
            buf.writeByte('(');
            floatToBuffer(e.type, creall(e.value));
            buf.writeByte('+');
            floatToBuffer(e.type, cimagl(e.value));
            buf.writestring("i)");
        }

        void visitIdentifier(IdentifierExp e)
        {
            if (this.hdrgen || this.ddoc)
                buf.writestring(e.ident.toHChars2());
            else
                buf.writestring(e.ident.toString());
        }

        void visitString(StringExp e)
        {
            if (e.hexString || e.sz == 8)
            {
                buf.writeByte('x');
                buf.writeByte('"');

                foreach (i; 0 .. e.len)
                    buf.printf("%0*llX", e.sz, e.getIndex(i));

                buf.writeByte('"');

                if (e.postfix)
                    buf.writeByte(e.postfix);
                return;
            }
            buf.writeByte('"');
            const o = buf.length;

            foreach (i; 0 .. e.len)
            {
                writeCharLiteral(buf, e.getCodeUnit(i));
            }

            if (this.ddoc)
                escapeDdocString(buf, o);

            buf.writeByte('"');

            if (e.postfix)
                buf.writeByte(e.postfix);
        }

        void visitInterpolation(InterpExp e)
        {
            buf.writeByte('i');
            buf.writeByte('"');
            const o = buf.length;

            foreach (idx, str; e.interpolatedSet.parts)
            {
                if (idx % 2 == 0)
                {
                    foreach (ch; str)
                        writeCharLiteral(buf, ch);
                }
                else
                {
                    buf.writeByte('$');
                    buf.writeByte('(');

                    foreach (ch; str)
                        buf.writeByte(ch);

                    buf.writeByte(')');
                }
            }

            if (this.ddoc)
                escapeDdocString(buf, o);

            buf.writeByte('"');

            if (e.postfix)
                buf.writeByte(e.postfix);

        }

        void visitArrayLiteral(ArrayLiteralExp e)
        {
            buf.writeByte('[');
            argsToBuffer(e.elements, buf, e.basis);
            buf.writeByte(']');
        }

        void visitAssocArrayLiteral(AssocArrayLiteralExp e)
        {
            buf.writeByte('[');
            foreach (i, key; *e.keys)
            {
                if (i)
                    buf.writestring(", ");
                expToBuffer(key, PREC.assign, buf);
                buf.writeByte(':');
                auto value = (*e.values)[i];
                expToBuffer(value, PREC.assign, buf);
            }
            buf.writeByte(']');
        }

        void visitStructLiteral(StructLiteralExp e)
        {
            buf.writestring(e.sd.toChars());
            buf.writeByte('(');
            // CTFE can generate struct literals that contain an AddrExp pointing
            // to themselves, need to avoid infinite recursion:
            // struct S { this(int){ this.s = &this; } S* s; }
            // const foo = new S(0);
            if (e.stageflags & stageToCBuffer)
                buf.writestring("<recursion>");
            else
            {
                const old = e.stageflags;
                e.stageflags |= stageToCBuffer;
                argsToBuffer(e.elements, buf);
                e.stageflags = old;
            }
            buf.writeByte(')');
        }

        void visitCompoundLiteral(CompoundLiteralExp e)
        {
            buf.writeByte('(');
            typeToBuffer(e.type, null, buf);
            buf.writeByte(')');
            initializerToBuffer(e.initializer, buf);
        }

        void visitScope(ScopeExp e)
        {
            if (e.sds.isTemplateInstance())
            {
                toCBuffer(e.sds, buf);
            }
            else if (this.ddoc)
            {
                // fixes bug 6491
                if (auto m = e.sds.isModule())
                    buf.writestring(m.md.toChars());
                else
                    buf.writestring(e.sds.toChars());
            }
            else
            {
                buf.writestring(e.sds.kind());
                buf.writeByte(' ');
                buf.writestring(e.sds.toChars());
            }
        }

        void visitNew(NewExp e)
        {
            if (e.thisexp)
            {
                expToBuffer(e.thisexp, PREC.primary, buf);
                buf.writeByte('.');
            }
            buf.writestring("new ");
            typeToBuffer(e.newtype, null, buf);
            if (e.arguments && e.arguments.length)
            {
                buf.writeByte('(');
                argsToBuffer(e.arguments, buf, null, e.names);
                buf.writeByte(')');
            }
        }

        void visitNewAnonClass(NewAnonClassExp e)
        {
            if (e.thisexp)
            {
                expToBuffer(e.thisexp, PREC.primary, buf);
                buf.writeByte('.');
            }
            buf.writestring("new");
            buf.writestring(" class ");
            if (e.arguments && e.arguments.length)
            {
                buf.writeByte('(');
                argsToBuffer(e.arguments, buf);
                buf.writeByte(')');
            }
            if (e.cd)
                toCBuffer(e.cd, buf);
        }

        void visitSymOff(SymOffExp e)
        {
            if (e.offset)
                buf.printf("(& %s%+lld)", e.var.toChars(), e.offset);
            else if (e.var.isTypeInfoDeclaration())
                buf.writestring(e.var.toChars());
            else
                buf.printf("& %s", e.var.toChars());
        }

        void visitTuple(TupleExp e)
        {
            if (e.e0)
            {
                buf.writeByte('(');
                expressionPrettyPrint(e.e0, buf);
                buf.writestring(", AliasSeq!(");
                argsToBuffer(e.exps, buf);
                buf.writestring("))");
            }
            else
            {
                buf.writestring("AliasSeq!(");
                argsToBuffer(e.exps, buf);
                buf.writeByte(')');
            }
        }

        void visitDeclaration(DeclarationExp e)
        {
            /* Normal dmd execution won't reach here - regular variable declarations
             * are handled in visit(ExpStatement), so here would be used only when
             * we'll directly call Expression.toChars() for debugging.
             */
            if (e.declaration)
            {
                if (auto var = e.declaration.isVarDeclaration())
                {
                    // For debugging use:
                    // - Avoid printing newline.
                    // - Intentionally use the format (Type var;)
                    //   which isn't correct as regular D code.
                    buf.writeByte('(');

                    visitVarDecl(var, false, buf);

                    buf.writeByte(';');
                    buf.writeByte(')');
                }
                else
                    toCBuffer(e.declaration, buf);
            }
        }

        void visitTraits(TraitsExp e)
        {
            buf.writestring("__traits(");
            if (e.ident)
                buf.writestring(e.ident.toString());
            if (e.args)
            {
                foreach (arg; *e.args)
                {
                    buf.writestring(", ");
                    objectToBuffer(arg, buf);
                }
            }
            buf.writeByte(')');
        }

        void visitIs(IsExp e)
        {
            buf.writestring("is(");
            typeToBuffer(e.targ, e.id, buf);
            if (e.tok2 != TOK.reserved)
            {
                buf.writeByte(' ');
                buf.writestring(Token.toString(e.tok));
                buf.writeByte(' ');
                buf.writestring(Token.toString(e.tok2));
            }
            else if (e.tspec)
            {
                if (e.tok == TOK.colon)
                    buf.writestring(" : ");
                else
                    buf.writestring(" == ");
                typeToBuffer(e.tspec, null, buf);
            }
            if (e.parameters && e.parameters.length)
            {
                buf.writestring(", ");
                visitTemplateParameters(e.parameters, buf);
            }
            buf.writeByte(')');
        }

        void visitUna(UnaExp e)
        {
            buf.writestring(expressionTypeToString(e.op));
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitLoweredAssignExp(LoweredAssignExp e)
        {
            if (this.vcg_ast)
            {
                expressionPrettyPrint(e.lowering, buf);
                return;
            }

            buf.writestring(expressionTypeToString((cast(BinExp) e).op));
        }

        void visitBin(BinExp e)
        {
            expToBuffer(e.e1, precedence[e.op], buf);
            buf.writeByte(' ');
            buf.writestring(expressionTypeToString(e.op));
            buf.writeByte(' ');
            expToBuffer(e.e2, cast(PREC)(precedence[e.op] + 1), buf);
        }

        void visitComma(CommaExp e)
        {
            // CommaExp is generated by the compiler so it shouldn't
            // appear in error messages or header files.
            // For now, this treats the case where the compiler
            // generates CommaExp for temporaries by calling
            // the `sideeffect.copyToTemp` function.
            auto ve = e.e2.isVarExp();

            // not a CommaExp introduced for temporaries, go on
            // the old path
            if (!ve || !(ve.var.storage_class & STC.temp))
            {
                visitBin(cast(BinExp) e);
                return;
            }

            // CommaExp that contain temporaries inserted via
            // `copyToTemp` are usually of the form
            // ((T __temp = exp), __tmp).
            // Asserts are here to easily spot
            // missing cases where CommaExp
            // are used for other constructs
            auto vd = ve.var.isVarDeclaration();
            assert(vd && vd._init);

            if (auto ei = vd._init.isExpInitializer())
            {
                Expression commaExtract;
                auto exp = ei.exp;
                if (auto ce = exp.isConstructExp())
                    commaExtract = ce.e2;
                else if (auto se = exp.isStructLiteralExp())
                    commaExtract = se;

                if (commaExtract)
                {
                    expToBuffer(commaExtract, precedence[exp.op], buf);
                    return;
                }
            }

            // not one of the known cases, go on the old path
            visitBin(cast(BinExp) e);
            return;
        }

        void visitAssert(AssertExp e)
        {
            buf.writestring("assert(");
            expToBuffer(e.e1, PREC.assign, buf);
            if (e.msg)
            {
                buf.writestring(", ");
                expToBuffer(e.msg, PREC.assign, buf);
            }
            buf.writeByte(')');
        }

        void visitDotId(DotIdExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            if (e.arrow)
                buf.writestring("->");
            else
                buf.writeByte('.');
            buf.writestring(e.ident.toString());
        }

        void visitDotTemplate(DotTemplateExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('.');
            buf.writestring(e.td.toChars());
        }

        void visitDotVar(DotVarExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('.');
            buf.writestring(e.var.toChars());
        }

        void visitDotTemplateInstance(DotTemplateInstanceExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('.');
            toCBuffer(e.ti, buf);
        }

        void visitDelegate(DelegateExp e)
        {
            buf.writeByte('&');
            if (!e.func.isNested() || e.func.needThis())
            {
                expToBuffer(e.e1, PREC.primary, buf);
                buf.writeByte('.');
            }
            buf.writestring(e.func.toChars());
        }

        void visitDotType(DotTypeExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('.');
            buf.writestring(e.sym.toChars());
        }

        void visitCall(CallExp e)
        {
            if (e.e1.op == EXP.type)
            {
                /* Avoid parens around type to prevent forbidden cast syntax:
                 *   (sometype)(arg1)
                 * This is ok since types in constructor calls
                 * can never depend on parens anyway
                 */
                expressionPrettyPrint(e.e1, buf);
            }
            else
                expToBuffer(e.e1, precedence[e.op], buf);
            buf.writeByte('(');
            argsToBuffer(e.arguments, buf, null, e.names);
            buf.writeByte(')');
        }

        void visitPtr(PtrExp e)
        {
            buf.writeByte('*');
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitDelete(DeleteExp e)
        {
            buf.writestring("delete ");
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitCast(CastExp e)
        {
            buf.writestring("cast(");

            if (e.to)
                typeToBuffer(e.to, null, buf);
            else
            {
                MODtoBuffer(buf, e.mod);
            }

            buf.writeByte(')');
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitVector(VectorExp e)
        {
            buf.writestring("cast(");
            typeToBuffer(e.to, null, buf);
            buf.writeByte(')');
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitSlice(SliceExp e)
        {
            expToBuffer(e.e1, precedence[e.op], buf);
            buf.writeByte('[');
            if (e.upr || e.lwr)
            {
                if (e.lwr)
                    sizeToBuffer(e.lwr, buf);
                else
                    buf.writeByte('0');
                buf.writestring("..");
                if (e.upr)
                    sizeToBuffer(e.upr, buf);
                else
                    buf.writeByte('$');
            }
            buf.writeByte(']');
        }

        void visitInterval(IntervalExp e)
        {
            expToBuffer(e.lwr, PREC.assign, buf);
            buf.writestring("..");
            expToBuffer(e.upr, PREC.assign, buf);
        }

        void visitDelegateFuncptr(DelegateFuncptrExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writestring(".funcptr");
        }

        void visitArray(ArrayExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('[');
            argsToBuffer(e.arguments, buf);
            buf.writeByte(']');
        }

        void visitDot(DotExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('.');
            expToBuffer(e.e2, PREC.primary, buf);
        }

        void visitIndex(IndexExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writeByte('[');
            sizeToBuffer(e.e2, buf);
            buf.writeByte(']');
        }

        void visitPost(PostExp e)
        {
            expToBuffer(e.e1, precedence[e.op], buf);
            buf.writestring(expressionTypeToString(e.op));
        }

        void visitPre(PreExp e)
        {
            buf.writestring(expressionTypeToString(e.op));
            expToBuffer(e.e1, precedence[e.op], buf);
        }

        void visitRemove(RemoveExp e)
        {
            expToBuffer(e.e1, PREC.primary, buf);
            buf.writestring(".remove(");
            expToBuffer(e.e2, PREC.assign, buf);
            buf.writeByte(')');
        }

        void visitCond(CondExp e)
        {
            expToBuffer(e.econd, PREC.oror, buf);
            buf.writestring(" ? ");
            expToBuffer(e.e1, PREC.expr, buf);
            buf.writestring(" : ");
            expToBuffer(e.e2, PREC.cond, buf);
        }

        switch (e.op)
        {
        default:
            if (auto be = e.isBinExp())
                return visitBin(be);
            else if (auto ue = e.isUnaExp())
                return visitUna(ue);
            else if (auto de = e.isDefaultInitExp())
            {
                buf.writestring(expressionTypeToString(e.isDefaultInitExp().op));
                return;
            }
            else
            {
                buf.writestring(expressionTypeToString(e.op));
                return;
            }

        case EXP.error:
            buf.writestring("__error");
            return;
        case EXP.this_:
            buf.writestring("this");
            return;
        case EXP.super_:
            buf.writestring("super");
            return;
        case EXP.null_:
            buf.writestring("null");
            return;
        case EXP.void_:
            buf.writestring("void");
            return;
        case EXP.halt:
            buf.writestring("halt");
            return;

        case EXP.function_:
            toCBuffer(e.isFuncExp().fd, buf);
            return;
        case EXP.classReference:
            buf.writestring(e.isClassReferenceExp().value.toChars());
            return;
        case EXP.arrayLength:
            expToBuffer(e.isArrayLengthExp().e1, PREC.primary, buf);
            buf.writestring(".length");
            return;
        case EXP.vectorArray:
            expToBuffer(e.isVectorArrayExp().e1, PREC.primary, buf);
            buf.writestring(".array");
            return;
        case EXP.throw_:
            buf.writestring("throw ");
            expToBuffer(e.isThrowExp().e1, PREC.unary, buf);
            return;
        case EXP.import_:
            buf.writestring("import(");
            expToBuffer(e.isImportExp().e1, PREC.assign, buf);
            buf.writeByte(')');
            return;
        case EXP.mixin_:
            buf.writestring("mixin(");
            argsToBuffer(e.isMixinExp().exps, buf, null);
            buf.writeByte(')');
            return;
        case EXP.typeid_:
            buf.writestring("typeid(");
            objectToBuffer(e.isTypeidExp().obj, buf);
            buf.writeByte(')');
            return;
        case EXP.overloadSet:
            buf.writestring(e.isOverExp().vars.ident.toString());
            return;
        case EXP.variable:
            buf.writestring(e.isVarExp().var.toChars());
            return;
        case EXP.template_:
            buf.writestring(e.isTemplateExp().td.toChars());
            return;
        case EXP.type:
            typeToBuffer(e.isTypeExp().type, null, buf);
            return;
        case EXP.dSymbol:
            buf.writestring(e.isDsymbolExp().s.toChars());
            return;
        case EXP.delegatePointer:
            expToBuffer(e.isDelegatePtrExp().e1, PREC.primary, buf);
            buf.writestring(".ptr");
            return;

        case EXP.int64:
            return visitInteger(e.isIntegerExp());
        case EXP.float64:
            return visitReal(e.isRealExp());
        case EXP.complex80:
            return visitComplex(e.isComplexExp());
        case EXP.identifier:
            return visitIdentifier(e.isIdentifierExp());
        case EXP.string_:
            return visitString(e.isStringExp());
        case EXP.interpolated:
            return visitInterpolation(e.isInterpExp());
        case EXP.arrayLiteral:
            return visitArrayLiteral(e.isArrayLiteralExp());
        case EXP.assocArrayLiteral:
            return visitAssocArrayLiteral(e.isAssocArrayLiteralExp());
        case EXP.structLiteral:
            return visitStructLiteral(e.isStructLiteralExp());
        case EXP.compoundLiteral:
            return visitCompoundLiteral(e.isCompoundLiteralExp());
        case EXP.scope_:
            return visitScope(e.isScopeExp());
        case EXP.new_:
            return visitNew(e.isNewExp());
        case EXP.newAnonymousClass:
            return visitNewAnonClass(e.isNewAnonClassExp());
        case EXP.symbolOffset:
            return visitSymOff(e.isSymOffExp());
        case EXP.tuple:
            return visitTuple(e.isTupleExp());
        case EXP.declaration:
            return visitDeclaration(e.isDeclarationExp());
        case EXP.traits:
            return visitTraits(e.isTraitsExp());
        case EXP.is_:
            return visitIs(e.isExp());
        case EXP.comma:
            return visitComma(e.isCommaExp());
        case EXP.assert_:
            return visitAssert(e.isAssertExp());
        case EXP.dotIdentifier:
            return visitDotId(e.isDotIdExp());
        case EXP.dotTemplateDeclaration:
            return visitDotTemplate(e.isDotTemplateExp());
        case EXP.dotVariable:
            return visitDotVar(e.isDotVarExp());
        case EXP.dotTemplateInstance:
            return visitDotTemplateInstance(e.isDotTemplateInstanceExp());
        case EXP.delegate_:
            return visitDelegate(e.isDelegateExp());
        case EXP.dotType:
            return visitDotType(e.isDotTypeExp());
        case EXP.call:
            return visitCall(e.isCallExp());
        case EXP.star:
            return visitPtr(e.isPtrExp());
        case EXP.delete_:
            return visitDelete(e.isDeleteExp());
        case EXP.cast_:
            return visitCast(e.isCastExp());
        case EXP.vector:
            return visitVector(e.isVectorExp());
        case EXP.slice:
            return visitSlice(e.isSliceExp());
        case EXP.interval:
            return visitInterval(e.isIntervalExp());
        case EXP.delegateFunctionPointer:
            return visitDelegateFuncptr(e.isDelegateFuncptrExp());
        case EXP.array:
            return visitArray(e.isArrayExp());
        case EXP.dot:
            return visitDot(e.isDotExp());
        case EXP.index:
            return visitIndex(e.isIndexExp());
        case EXP.minusMinus, EXP.plusPlus:
            return visitPost(e.isPostExp());
        case EXP.preMinusMinus, EXP.prePlusPlus:
            return visitPre(e.isPreExp());
        case EXP.remove:
            return visitRemove(e.isRemoveExp());
        case EXP.question:
            return visitCond(e.isCondExp());

        case EXP.loweredAssignExp:
            return visitLoweredAssignExp(e.isLoweredAssignExp());
        }
    }

    void initializerToBuffer(Initializer inx, ref OutBuffer buf)
    {
        void visitError(ErrorInitializer iz)
        {
            buf.writestring("__error__");
        }

        void visitVoid(VoidInitializer iz)
        {
            buf.writestring("void");
        }

        void visitDefault(DefaultInitializer iz)
        {
            buf.writestring("{ }");
        }

        void visitStruct(StructInitializer si)
        {
            //printf("StructInitializer::toCBuffer()\n");
            buf.writeByte('{');
            foreach (i, const id; si.field)
            {
                if (i)
                    buf.writestring(", ");
                if (id)
                {
                    buf.writestring(id.toString());
                    buf.writeByte(':');
                }
                if (auto iz = si.value[i])
                    initializerToBuffer(iz, buf);
            }
            buf.writeByte('}');
        }

        void visitArray(ArrayInitializer ai)
        {
            buf.writeByte('[');
            foreach (i, ex; ai.index)
            {
                if (i)
                    buf.writestring(", ");
                if (ex)
                {
                    expressionPrettyPrint(ex, buf);
                    buf.writeByte(':');
                }
                if (auto iz = ai.value[i])
                    initializerToBuffer(iz, buf);
            }
            buf.writeByte(']');
        }

        void visitExp(ExpInitializer ei)
        {
            expressionPrettyPrint(ei.exp, buf);
        }

        void visitC(CInitializer ci)
        {
            buf.writeByte('{');
            foreach (i, ref DesigInit di; ci.initializerList)
            {
                if (i)
                    buf.writestring(", ");
                if (di.designatorList)
                {
                    foreach (ref Designator d; (*di.designatorList)[])
                    {
                        if (d.exp)
                        {
                            buf.writeByte('[');
                            toCBuffer(d.exp, buf);
                            buf.writeByte(']');
                        }
                        else
                        {
                            buf.writeByte('.');
                            buf.writestring(d.ident.toString());
                        }
                    }
                    buf.writeByte('=');
                }
                initializerToBuffer(di.initializer, buf);
            }
            buf.writeByte('}');
        }

        mixin VisitInitializer!void visit;
        visit.VisitInitializer(inx);
    }

    void sizeToBuffer(Expression e, ref OutBuffer buf)
    {
        if (e.type == Type.tsize_t)
        {
            Expression ex = (e.op == EXP.cast_ ? (cast(CastExp) e).e1 : e);
            ex = ex.optimize(WANTvalue);

            const ulong uval = ex.op == EXP.int64 ? ex.toInteger() : cast(ulong)-1;
            if (cast(long) uval >= 0)
            {
                if (uval <= 0xFFFFU)
                {
                    buf.print(uval);
                    return;
                }

                if (uval <= 0x7FFF_FFFF_FFFF_FFFFUL)
                {
                    buf.writestring("cast(size_t)");
                    buf.print(uval);
                    return;
                }
            }
        }

        expToBuffer(e, PREC.assign, buf);
    }

    /**
        This makes a 'pretty' version of the template arguments.
        It's analogous to genIdent() which makes a mangled version.
    */
    void objectToBuffer(RootObject oarg, ref OutBuffer buf)
    {
        //printf("objectToBuffer()\n");
        /* The logic of this should match what genIdent() does. The _dynamic_cast()
         * function relies on all the pretty strings to be unique for different classes
         * See https://issues.dlang.org/show_bug.cgi?id=7375
         * Perhaps it would be better to demangle what genIdent() does.
         */

        if (auto t = isType(oarg))
        {
            //printf("\tt: %s ty = %d\n", t.toChars(), t.ty);
            typeToBuffer(t, null, buf);
        }
        else if (auto e = isExpression(oarg))
        {
            if (e.op == EXP.variable)
                e = e.optimize(WANTvalue); // added to fix https://issues.dlang.org/show_bug.cgi?id=7375

            expToBuffer(e, PREC.assign, buf);
        }
        else if (Dsymbol s = isDsymbol(oarg))
        {
            if (s.ident)
                buf.writestring(s.ident.toString());
            else
                buf.writestring(s.toChars());
        }
        else if (auto v = isTuple(oarg))
        {
            auto args = &v.objects;

            foreach (i, arg; *args)
            {
                if (i)
                    buf.writestring(", ");

                objectToBuffer(arg, buf);
            }
        }
        else if (auto p = isParameter(oarg))
        {
            parameterToBuffer(p, buf);
        }
        else if (!oarg)
        {
            buf.writestring("NULL");
        }
        else
        {
            debug
            {
                printf("bad Object = %p\n", oarg);
            }
            assert(0);
        }
    }

    /**
        Pretty-print a template parameter list to a buffer.
     */
    void visitTemplateParameters(TemplateParameters* parameters, ref OutBuffer buf)
    {
        if (!parameters)
            return;

        foreach (i, p; *parameters)
        {
            if (i)
                buf.writestring(", ");

            toCBuffer(p, buf);
        }
    }

    /**
        Pretty-print a VarDeclaration to buf.
     */
    void visitVarDecl(VarDeclaration v, bool anywritten, ref OutBuffer buf)
    {
        const bool isextern = this.hdrgen && !this.insideFuncBody && !this.tpltMember
            && !this.insideAggregate && !(v.storage_class & STC.manifest);

        void vinit(VarDeclaration v)
        {
            auto ie = v._init.isExpInitializer();
            if (ie && (ie.exp.op == EXP.construct || ie.exp.op == EXP.blit))
                expressionPrettyPrint((cast(AssignExp) ie.exp).e2, buf);
            else
                initializerToBuffer(v._init, buf);
        }

        const commentIt = this.importcHdr && isSpecialCName(v.ident);
        if (commentIt)
            buf.writestring("/+");

        if (anywritten)
        {
            buf.writestring(", ");
            buf.writestring(v.ident.toString());
        }
        else
        {
            const bool useTypeof = isextern && v._init && !v.type;
            auto stc = v.storage_class;

            if (isextern)
                stc |= STC.extern_;

            if (useTypeof)
                stc &= ~STC.auto_;

            if (storageClassToBuffer(buf, stc))
                buf.writeByte(' ');

            if (v.type)
                typeToBuffer(v.type, v.ident, buf);
            else if (useTypeof)
            {
                buf.writestring("typeof(");
                vinit(v);
                buf.writestring(") ");
                buf.writestring(v.ident.toString());
            }
            else
                buf.writestring(v.ident.toString());
        }

        if (v._init && !isextern)
        {
            buf.writestring(" = ");
            vinit(v);
        }
        if (commentIt)
            buf.writestring("+/");
    }

    void typeToBufferx(Type t, ref OutBuffer buf)
    {
        void visitVector(TypeVector t)
        {
            //printf("TypeVector::toCBuffer2(t.mod = %d)\n", t.mod);
            buf.writestring("__vector(");
            visitWithMask(t.basetype, t.mod, buf);
            buf.writestring(")");
        }

        void visitSArray(TypeSArray t)
        {
            visitWithMask(t.next, t.mod, buf);
            buf.writeByte('[');
            sizeToBuffer(t.dim, buf);
            buf.writeByte(']');
        }

        void visitDArray(TypeDArray t)
        {
            Type ut = t.castMod(0);
            if (this.declstring)
                goto L1;
            if (ut.equals(Type.tstring))
                buf.writestring("string");
            else if (ut.equals(Type.twstring))
                buf.writestring("wstring");
            else if (ut.equals(Type.tdstring))
                buf.writestring("dstring");
            else
            {
            L1:
                visitWithMask(t.next, t.mod, buf);
                buf.writestring("[]");
            }
        }

        void visitAArray(TypeAArray t)
        {
            visitWithMask(t.next, t.mod, buf);
            buf.writeByte('[');
            visitWithMask(t.index, 0, buf);
            buf.writeByte(']');
        }

        void visitPointer(TypePointer t)
        {
            //printf("TypePointer::toCBuffer2() next = %d\n", t.next.ty);
            if (t.next.ty == Tfunction)
                functionSignatureToBufferAsPostfix(cast(TypeFunction) t.next,
                        buf, "function", false);
            else
            {
                visitWithMask(t.next, t.mod, buf);
                buf.writeByte('*');
            }
        }

        void visitReference(TypeReference t)
        {
            visitWithMask(t.next, t.mod, buf);
            buf.writeByte('&');
        }

        void visitTypeQualifiedHelper(TypeQualified t)
        {
            foreach (id; t.idents)
            {
                switch (id.dyncast()) with (DYNCAST)
                {
                case dsymbol:
                    buf.writeByte('.');
                    TemplateInstance ti = cast(TemplateInstance) id;
                    toCBuffer(ti, buf);
                    break;
                case expression:
                    buf.writeByte('[');
                    expressionPrettyPrint(cast(Expression) id, buf);
                    buf.writeByte(']');
                    break;
                case type:
                    buf.writeByte('[');
                    typeToBufferx(cast(Type) id, buf);
                    buf.writeByte(']');
                    break;
                default:
                    buf.writeByte('.');
                    buf.writestring(id.toString());
                }
            }
        }

        void visitIdentifier(TypeIdentifier t)
        {
            //printf("visitTypeIdentifier() %s\n", t.ident.toChars());
            buf.writestring(t.ident.toString());
            visitTypeQualifiedHelper(t);
        }

        void visitInstance(TypeInstance t)
        {
            toCBuffer(t.tempinst, buf);
            visitTypeQualifiedHelper(t);
        }

        void visitTypeof(TypeTypeof t)
        {
            buf.writestring("typeof(");
            expressionPrettyPrint(t.exp, buf);
            buf.writeByte(')');
            visitTypeQualifiedHelper(t);
        }

        void visitEnum(TypeEnum t)
        {
            //printf("visitEnum: %s\n", t.sym.toChars());
            buf.writestring(this.fullQual ? t.sym.toPrettyChars() : t.sym.toChars());
        }

        void visitStruct(TypeStruct t)
        {
            //printf("visitTypeStruct() %s\n", t.sym.toChars());

            // https://issues.dlang.org/show_bug.cgi?id=13776
            // Don't use ti.toAlias() to avoid forward reference error
            // while printing messages.
            TemplateInstance ti = t.sym.parent ? t.sym.parent.isTemplateInstance() : null;
            if (ti && ti.aliasdecl == t.sym)
                buf.writestring(this.fullQual ? ti.toPrettyChars() : ti.toChars());
            else
                buf.writestring(this.fullQual ? t.sym.toPrettyChars() : t.sym.toChars());
        }

        void visitClass(TypeClass t)
        {
            // https://issues.dlang.org/show_bug.cgi?id=13776
            // Don't use ti.toAlias() to avoid forward reference error
            // while printing messages.
            TemplateInstance ti = t.sym.parent ? t.sym.parent.isTemplateInstance() : null;
            if (ti && ti.aliasdecl == t.sym)
                buf.writestring(this.fullQual ? ti.toPrettyChars() : ti.toChars());
            else
                buf.writestring(this.fullQual ? t.sym.toPrettyChars() : t.sym.toChars());
        }

        void visitTag(TypeTag t)
        {
            if (t.mod & MODFlags.const_)
                buf.writestring("const ");
            if (this.importcHdr && t.id)
            {
                buf.writestring(t.id.toString());
                return;
            }
            buf.writestring(Token.toString(t.tok));
            buf.writeByte(' ');
            if (t.id)
                buf.writestring(t.id.toString());
            if (t.tok == TOK.enum_ && t.base && t.base.ty != TY.Tint32)
            {
                buf.writestring(" : ");
                visitWithMask(t.base, t.mod, buf);
            }
        }

        void visitSlice(TypeSlice t)
        {
            visitWithMask(t.next, t.mod, buf);
            buf.writeByte('[');
            sizeToBuffer(t.lwr, buf);
            buf.writestring(" .. ");
            sizeToBuffer(t.upr, buf);
            buf.writeByte(']');
        }

        switch (t.ty)
        {
        default:
            if (t.isTypeBasic())
                buf.writestring((cast(TypeBasic) t).dstring);
            else
            {
                printf("t = %p, ty = %d\n", t, t.ty);
                assert(0);
            }
            return;

        case Tnoreturn:
            buf.writestring("noreturn");
            return;
        case Tnull:
            buf.writestring("typeof(null)");
            return;
        case Terror:
            buf.writestring("_error_");
            return;

        case Ttuple:
            parametersToBuffer(ParameterList((cast(TypeTuple) t).arguments, VarArg.none), buf);
            return;
        case Tdelegate:
            functionSignatureToBufferAsPostfix(cast(TypeFunction)(cast(TypeDelegate) t)
                    .next, buf, "delegate", false);
            return;
        case Tfunction:
            functionSignatureToBufferAsPostfix(cast(TypeFunction) t, buf, null, false);
            return;
        case Tmixin:
            buf.writestring("mixin(");
            argsToBuffer((cast(TypeMixin) t).exps, buf, null);
            buf.writeByte(')');
            return;
        case Treturn:
            buf.writestring("typeof(return)");
            visitTypeQualifiedHelper(cast(TypeReturn) t);
            return;
        case Ttraits:
            expressionPrettyPrint((cast(TypeTraits) t).exp, buf);
            return;

        case Tvector:
            return visitVector(cast(TypeVector) t);
        case Tsarray:
            return visitSArray(cast(TypeSArray) t);
        case Tarray:
            return visitDArray(cast(TypeDArray) t);
        case Taarray:
            return visitAArray(cast(TypeAArray) t);
        case Tpointer:
            return visitPointer(cast(TypePointer) t);
        case Treference:
            return visitReference(cast(TypeReference) t);

        case Tident:
            return visitIdentifier(cast(TypeIdentifier) t);
        case Tinstance:
            return visitInstance(cast(TypeInstance) t);
        case Ttypeof:
            return visitTypeof(cast(TypeTypeof) t);
        case Tenum:
            return visitEnum(cast(TypeEnum) t);
        case Tstruct:
            return visitStruct(cast(TypeStruct) t);
        case Tclass:
            return visitClass(cast(TypeClass) t);

        case Tslice:
            return visitSlice(cast(TypeSlice) t);

        case Ttag:
            return visitTag(cast(TypeTag) t);
        }
    }

    void moduleToBuffer(Module m, ref OutBuffer buf)
    {
        if (m.md)
        {
            if (m.userAttribDecl)
            {
                buf.writestring("@(");
                argsToBuffer(m.userAttribDecl.atts, buf);
                buf.writeByte(')');
                buf.writenl();
            }
            if (m.md.isdeprecated)
            {
                if (m.md.msg)
                {
                    buf.writestring("deprecated(");
                    expressionPrettyPrint(m.md.msg, buf);
                    buf.writestring(") ");
                }
                else
                    buf.writestring("deprecated ");
            }
            buf.writestring("module ");
            buf.writestring(m.md.toChars());
            buf.writeByte(';');
            buf.writenl();
        }

        foreach (s; *m.members)
        {
            toCBuffer(s, buf);
        }
    }

    void dumpTemplateInstance(TemplateInstance ti, ref OutBuffer buf)
    {
        buf.writeByte('{');
        buf.writenl();
        buf.level++;

        if (ti.aliasdecl)
        {
            this.toCBuffer(ti.aliasdecl, buf);
            buf.writenl();
        }
        else if (ti.members)
        {
            foreach (m; *ti.members)
                this.toCBuffer(m, buf);
        }

        buf.level--;
        buf.writeByte('}');
        buf.writenl();
    }

    void tiargsToBuffer(TemplateInstance ti, ref OutBuffer buf)
    {
        buf.writeByte('!');

        if (ti.nest)
        {
            buf.writestring("(...)");
            return;
        }
        else if (!ti.tiargs)
        {
            buf.writestring("()");
            return;
        }
        else if (ti.tiargs.length == 1)
        {
            RootObject oarg = (*ti.tiargs)[0];

            if (Type t = isType(oarg))
            {
                if (t.equals(Type.tstring) || t.equals(Type.twstring)
                        || t.equals(Type.tdstring) || t.mod == 0 && (t.isTypeBasic()
                            || t.ty == Tident && (cast(TypeIdentifier) t).idents.length == 0))
                {
                    HdrGenState hgs2 = this; // re-examine need for new hgs
                    hgs2.fullQual = (t.ty == Tclass && !t.mod);
                    hgs2.toCBuffer(t, buf, null);
                    return;
                }
            }
            else if (Expression e = isExpression(oarg))
            {
                if (e.op == EXP.int64 || e.op == EXP.float64 || e.op == EXP.null_
                        || e.op == EXP.string_ || e.op == EXP.this_)
                {
                    toCBuffer(e, buf);
                    return;
                }
            }
        }

        buf.writeByte('(');
        ti.nestUp();

        foreach (i, arg; *ti.tiargs)
        {
            if (i)
                buf.writestring(", ");

            objectToBuffer(arg, buf);
        }

        ti.nestDown();
        buf.writeByte(')');
    }

    void statementToBuffer(Statement s, ref OutBuffer buf)
    {
        void visitDefaultCase(Statement s)
        {
            printf("Statement::toCBuffer() %d\n", s.stmt);
            assert(0, "unrecognized statement in statementToBuffer()");
        }

        void visitError(ErrorStatement s)
        {
            buf.writestring("__error__");
            buf.writenl();
        }

        void visitExp(ExpStatement s)
        {
            if (s.exp && s.exp.op == EXP.declaration && (cast(DeclarationExp) s.exp).declaration)
            {
                // bypass visit(DeclarationExp)
                toCBuffer((cast(DeclarationExp) s.exp).declaration, buf);
                return;
            }

            if (s.exp)
                expressionPrettyPrint(s.exp, buf);

            buf.writeByte(';');

            if (!this.forStmtInit)
                buf.writenl();
        }

        void visitDtorExp(DtorExpStatement s)
        {
            visitExp(s);
        }

        void visitMixin(MixinStatement s)
        {
            buf.writestring("mixin(");
            argsToBuffer(s.exps, buf, null);
            buf.writestring(");");

            if (!this.forStmtInit)
                buf.writenl();
        }

        void visitCompound(CompoundStatement s)
        {
            foreach (sx; *s.statements)
            {
                if (sx)
                    statementToBuffer(sx, buf);
            }
        }

        void visitCompoundAsm(CompoundAsmStatement s)
        {
            visitCompound(s);
        }

        void visitCompoundDeclaration(CompoundDeclarationStatement s)
        {
            bool anywritten = false;

            foreach (sx; *s.statements)
            {
                auto ds = sx ? sx.isExpStatement() : null;
                if (ds && ds.exp.isDeclarationExp())
                {
                    auto d = ds.exp.isDeclarationExp().declaration;

                    if (auto v = d.isVarDeclaration())
                    {
                        visitVarDecl(v, anywritten, buf);
                    }
                    else
                        toCBuffer(d, buf);

                    anywritten = true;
                }
            }

            buf.writeByte(';');
            if (!this.forStmtInit)
                buf.writenl();
        }

        void visitUnrolledLoop(UnrolledLoopStatement s)
        {
            buf.writestring("/*unrolled*/ {");
            buf.writenl();
            buf.level++;

            foreach (sx; *s.statements)
            {
                if (sx)
                    statementToBuffer(sx, buf);
            }

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visitScope(ScopeStatement s)
        {
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            if (s.statement)
                statementToBuffer(s.statement, buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visitWhile(WhileStatement s)
        {
            buf.writestring("while (");

            if (auto p = s.param)
            {
                // Print condition assignment
                StorageClass stc = p.storageClass;

                if (!p.type && !stc)
                    stc = STC.auto_;

                if (storageClassToBuffer(buf, stc))
                    buf.writeByte(' ');

                if (p.type)
                    typeToBuffer(p.type, p.ident, buf);
                else
                    buf.writestring(p.ident.toString());

                buf.writestring(" = ");
            }

            expressionPrettyPrint(s.condition, buf);
            buf.writeByte(')');
            buf.writenl();

            if (s._body)
                statementToBuffer(s._body, buf);
        }

        void visitDo(DoStatement s)
        {
            buf.writestring("do");
            buf.writenl();

            if (s._body)
                statementToBuffer(s._body, buf);

            buf.writestring("while (");
            expressionPrettyPrint(s.condition, buf);
            buf.writestring(");");
            buf.writenl();
        }

        void visitFor(ForStatement s)
        {
            buf.writestring("for (");

            if (s._init)
            {
                this.forStmtInit++;
                statementToBuffer(s._init, buf);
                this.forStmtInit--;
            }
            else
                buf.writeByte(';');

            if (s.condition)
            {
                buf.writeByte(' ');
                expressionPrettyPrint(s.condition, buf);
            }

            buf.writeByte(';');

            if (s.increment)
            {
                buf.writeByte(' ');
                expressionPrettyPrint(s.increment, buf);
            }

            buf.writeByte(')');
            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            if (s._body)
                statementToBuffer(s._body, buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void foreachWithoutBody(ForeachStatement s)
        {
            buf.writestring(Token.toString(s.op));
            buf.writestring(" (");

            foreach (i, p; *s.parameters)
            {
                if (i)
                    buf.writestring(", ");

                if (storageClassToBuffer(buf, p.storageClass))
                    buf.writeByte(' ');

                if (p.type)
                    typeToBuffer(p.type, p.ident, buf);
                else
                    buf.writestring(p.ident.toString());
            }

            buf.writestring("; ");
            expressionPrettyPrint(s.aggr, buf);
            buf.writeByte(')');
            buf.writenl();
        }

        void visitForeach(ForeachStatement s)
        {
            foreachWithoutBody(s);
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            if (s._body)
                statementToBuffer(s._body, buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void foreachRangeWithoutBody(ForeachRangeStatement s)
        {
            buf.writestring(Token.toString(s.op));
            buf.writestring(" (");

            if (s.prm.type)
                typeToBuffer(s.prm.type, s.prm.ident, buf);
            else
                buf.writestring(s.prm.ident.toString());

            buf.writestring("; ");
            expressionPrettyPrint(s.lwr, buf);
            buf.writestring(" .. ");
            expressionPrettyPrint(s.upr, buf);
            buf.writeByte(')');
            buf.writenl();
        }

        void visitForeachRange(ForeachRangeStatement s)
        {
            foreachRangeWithoutBody(s);
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            if (s._body)
                statementToBuffer(s._body, buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visitStaticForeach(StaticForeachStatement s)
        {
            buf.writestring("static ");

            if (s.sfe.aggrfe)
            {
                visitForeach(s.sfe.aggrfe);
            }
            else
            {
                assert(s.sfe.rangefe);
                visitForeachRange(s.sfe.rangefe);
            }
        }

        void visitForwarding(ForwardingStatement s)
        {
            statementToBuffer(s.statement, buf);
        }

        void visitIf(IfStatement s)
        {
            buf.writestring("if (");

            if (Parameter p = s.prm)
            {
                StorageClass stc = p.storageClass;

                if (!p.type && !stc)
                    stc = STC.auto_;

                if (storageClassToBuffer(buf, stc))
                    buf.writeByte(' ');

                if (p.type)
                    typeToBuffer(p.type, p.ident, buf);
                else
                    buf.writestring(p.ident.toString());

                buf.writestring(" = ");
            }

            expressionPrettyPrint(s.condition, buf);
            buf.writeByte(')');
            buf.writenl();

            if (s.ifbody.isScopeStatement())
            {
                statementToBuffer(s.ifbody, buf);
            }
            else
            {
                buf.level++;
                statementToBuffer(s.ifbody, buf);
                buf.level--;
            }

            if (s.elsebody)
            {
                buf.writestring("else");

                if (!s.elsebody.isIfStatement())
                {
                    buf.writenl();
                }
                else
                {
                    buf.writeByte(' ');
                }

                if (s.elsebody.isScopeStatement() || s.elsebody.isIfStatement())
                {
                    statementToBuffer(s.elsebody, buf);
                }
                else
                {
                    buf.level++;
                    statementToBuffer(s.elsebody, buf);
                    buf.level--;
                }
            }
        }

        void visitConditional(ConditionalStatement s)
        {
            conditionToBuffer(s.condition, buf);

            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            if (s.ifbody)
                statementToBuffer(s.ifbody, buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();

            if (s.elsebody)
            {
                buf.writestring("else");
                buf.writenl();
                buf.writeByte('{');
                buf.level++;
                buf.writenl();
                statementToBuffer(s.elsebody, buf);
                buf.level--;
                buf.writeByte('}');
            }

            buf.writenl();
        }

        void visitPragma(PragmaStatement s)
        {
            buf.writestring("pragma (");
            buf.writestring(s.ident.toString());

            if (s.args && s.args.length)
            {
                buf.writestring(", ");
                argsToBuffer(s.args, buf);
            }

            buf.writeByte(')');

            if (s._body)
            {
                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;
                statementToBuffer(s._body, buf);
                buf.level--;
                buf.writeByte('}');
                buf.writenl();
            }
            else
            {
                buf.writeByte(';');
                buf.writenl();
            }
        }

        void visitStaticAssert(StaticAssertStatement s)
        {
            toCBuffer(s.sa, buf);
        }

        void visitSwitch(SwitchStatement s)
        {
            buf.writestring(s.isFinal ? "final switch (" : "switch (");

            if (auto p = s.param)
            {
                // Print condition assignment
                StorageClass stc = p.storageClass;

                if (!p.type && !stc)
                    stc = STC.auto_;

                if (storageClassToBuffer(buf, stc))
                    buf.writeByte(' ');

                if (p.type)
                    typeToBuffer(p.type, p.ident, buf);
                else
                    buf.writestring(p.ident.toString());

                buf.writestring(" = ");
            }

            expressionPrettyPrint(s.condition, buf);
            buf.writeByte(')');
            buf.writenl();

            if (s._body)
            {
                if (!s._body.isScopeStatement())
                {
                    buf.writeByte('{');
                    buf.writenl();
                    buf.level++;
                    statementToBuffer(s._body, buf);
                    buf.level--;
                    buf.writeByte('}');
                    buf.writenl();
                }
                else
                {
                    statementToBuffer(s._body, buf);
                }
            }
        }

        void visitCase(CaseStatement s)
        {
            buf.writestring("case ");
            expressionPrettyPrint(s.exp, buf);
            buf.writeByte(':');
            buf.writenl();
            statementToBuffer(s.statement, buf);
        }

        void visitCaseRange(CaseRangeStatement s)
        {
            buf.writestring("case ");
            expressionPrettyPrint(s.first, buf);
            buf.writestring(": .. case ");
            expressionPrettyPrint(s.last, buf);
            buf.writeByte(':');
            buf.writenl();
            statementToBuffer(s.statement, buf);
        }

        void visitDefault(DefaultStatement s)
        {
            buf.writestring("default:");
            buf.writenl();
            statementToBuffer(s.statement, buf);
        }

        void visitGotoDefault(GotoDefaultStatement s)
        {
            buf.writestring("goto default;");
            buf.writenl();
        }

        void visitGotoCase(GotoCaseStatement s)
        {
            buf.writestring("goto case");

            if (s.exp)
            {
                buf.writeByte(' ');
                expressionPrettyPrint(s.exp, buf);
            }

            buf.writeByte(';');
            buf.writenl();
        }

        void visitSwitchError(SwitchErrorStatement s)
        {
            buf.writestring("SwitchErrorStatement::toCBuffer()");
            buf.writenl();
        }

        void visitReturn(ReturnStatement s)
        {
            buf.writestring("return ");

            if (s.exp)
                expressionPrettyPrint(s.exp, buf);

            buf.writeByte(';');
            buf.writenl();
        }

        void visitBreak(BreakStatement s)
        {
            buf.writestring("break");

            if (s.ident)
            {
                buf.writeByte(' ');
                buf.writestring(s.ident.toString());
            }

            buf.writeByte(';');
            buf.writenl();
        }

        void visitContinue(ContinueStatement s)
        {
            buf.writestring("continue");

            if (s.ident)
            {
                buf.writeByte(' ');
                buf.writestring(s.ident.toString());
            }

            buf.writeByte(';');
            buf.writenl();
        }

        void visitSynchronized(SynchronizedStatement s)
        {
            buf.writestring("synchronized");

            if (s.exp)
            {
                buf.writeByte('(');
                expressionPrettyPrint(s.exp, buf);
                buf.writeByte(')');
            }

            if (s._body)
            {
                buf.writeByte(' ');
                statementToBuffer(s._body, buf);
            }
        }

        void visitWith(WithStatement s)
        {
            buf.writestring("with (");
            expressionPrettyPrint(s.exp, buf);
            buf.writestring(")");
            buf.writenl();

            if (s._body)
                statementToBuffer(s._body, buf);
        }

        void visitTryCatch(TryCatchStatement s)
        {
            buf.writestring("try");
            buf.writenl();

            if (s._body)
            {
                if (s._body.isScopeStatement())
                {
                    statementToBuffer(s._body, buf);
                }
                else
                {
                    buf.level++;
                    statementToBuffer(s._body, buf);
                    buf.level--;
                }
            }

            foreach (c; *s.catches)
            {
                buf.writestring("catch");

                if (c.type)
                {
                    buf.writeByte('(');
                    typeToBuffer(c.type, c.ident, buf);
                    buf.writeByte(')');
                }

                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;

                if (c.handler)
                    statementToBuffer(c.handler, buf);

                buf.level--;
                buf.writeByte('}');
                buf.writenl();
            }
        }

        void visitTryFinally(TryFinallyStatement s)
        {
            buf.writestring("try");
            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;
            statementToBuffer(s._body, buf);
            buf.level--;
            buf.writeByte('}');
            buf.writenl();
            buf.writestring("finally");
            buf.writenl();

            if (s.finalbody.isScopeStatement())
            {
                statementToBuffer(s.finalbody, buf);
            }
            else
            {
                buf.level++;
                statementToBuffer(s.finalbody, buf);
                buf.level--;
            }
        }

        void visitScopeGuard(ScopeGuardStatement s)
        {
            buf.writestring(Token.toString(s.tok));
            buf.writeByte(' ');

            if (s.statement)
                statementToBuffer(s.statement, buf);
        }

        void visitThrow(ThrowStatement s)
        {
            buf.writestring("throw ");
            expressionPrettyPrint(s.exp, buf);
            buf.writeByte(';');
            buf.writenl();
        }

        void visitDebug(DebugStatement s)
        {
            if (s.statement)
            {
                statementToBuffer(s.statement, buf);
            }
        }

        void visitGoto(GotoStatement s)
        {
            buf.writestring("goto ");
            buf.writestring(s.ident.toString());
            buf.writeByte(';');
            buf.writenl();
        }

        void visitLabel(LabelStatement s)
        {
            buf.writestring(s.ident.toString());
            buf.writeByte(':');
            buf.writenl();

            if (s.statement)
                statementToBuffer(s.statement, buf);
        }

        void visitAsm(AsmStatement s)
        {
            buf.writestring("asm { ");
            Token* t = s.tokens;
            buf.level++;

            while (t)
            {
                buf.writestring(t.toString());

                if (t.next && t.value != TOK.min && t.value != TOK.comma
                        && t.next.value != TOK.comma && t.value != TOK.leftBracket
                        && t.next.value != TOK.leftBracket && t.next.value != TOK.rightBracket
                        && t.value != TOK.leftParenthesis && t.next.value != TOK.leftParenthesis
                        && t.next.value != TOK.rightParenthesis
                        && t.value != TOK.dot && t.next.value != TOK.dot)
                {
                    buf.writeByte(' ');
                }

                t = t.next;
            }

            buf.level--;
            buf.writestring("; }");
            buf.writenl();
        }

        void visitInlineAsm(InlineAsmStatement s)
        {
            visitAsm(s);
        }

        void visitGccAsm(GccAsmStatement s)
        {
            visitAsm(s);
        }

        void visitImport(ImportStatement s)
        {
            foreach (imp; *s.imports)
            {
                toCBuffer(imp, buf);
            }
        }

        mixin VisitStatement!void visit;
        visit.VisitStatement(s);
    }

    void conditionToBuffer(Condition c, ref OutBuffer buf)
    {
        scope v = new ConditionPrettyPrintVisitor;
        v.buf = &buf;
        v.hgs = &this;

        c.accept(v);
    }

    // Gives stronger control over identifier and parameters to emit.
    void writeTypeFunctionAttributes(TypeFunction tf, ref OutBuffer buf, ulong lhsStorageClasses,
            ulong rhsStorageClasses, scope void delegate(TypeFunction) writeFuncDel)
    {
        {
            // Prefix storage classes, used for semantic 3

            if (storageClassToBuffer(buf, lhsStorageClasses))
                buf.writeByte(' ');
        }

        writeFuncDel(tf);

        {
            // postfix attributes and storage classes

            void postfixWriteAttribute(string str)
            {
                buf.writeByte(' ');
                buf.writestring(str);
            }

            // Used for when semantic < 3
            const stcOffset = buf.length;
            const wroteSTCPostfix = storageClassToBuffer(buf, rhsStorageClasses);

            if (wroteSTCPostfix)
            {
                buf.insert(stcOffset, " ");
            }
            else if (tf !is null)
            {
                if (tf.mod)
                {
                    buf.writeByte(' ');
                    MODtoBuffer(buf, tf.mod);
                }

                tf.attributesApply(&postfixWriteAttribute);
            }
        }
    }

    extern (C++) final class DsymbolPrettyPrintVisitor : Visitor
    {
        alias visit = Visitor.visit;

        HdrGenState* hgs;
        OutBuffer* buf;
        bool doTrace;

        extern (D) void trace(string func = __PRETTY_FUNCTION__)
        {
            if (!doTrace)
                return;

            enum ToSlice = "extern (C++) void dmd.hdrgen.HdrGenState.DsymbolPrettyPrintVisitor.";

            printf("%*s %s\n", hgs.childCountOfModule * 2, "".ptr, func[ToSlice.length .. $].ptr);
        }

    public:
        void visitBaseClasses(ClassDeclaration d)
        {
            if (!d || !d.baseclasses.length)
                return;

            size_t i;
            foreach (b; *d.baseclasses)
            {
                if (b.sym !is ClassDeclaration.object)
                {
                    if (i)
                        buf.writestring(", ");
                    else if (!d.isAnonymous())
                        buf.writestring(" : ");

                    i++;
                    hgs.typeToBuffer(b.type, null, *buf);
                }
            }
        }

        bool visitEponymousMember(TemplateDeclaration d)
        {
            if (!d.members || d.members.length != 1)
                return false;

            Dsymbol onemember = (*d.members)[0];
            if (onemember.ident != d.ident)
                return false;

            if (FuncDeclaration fd = onemember.isFuncDeclaration())
            {
                assert(fd.type);
                if (storageClassToBuffer(*buf, fd.storage_class))
                    buf.writeByte(' ');

                hgs.functionSignatureToBuffer(cast(TypeFunction) fd.type, *buf, d.ident, d);
                visitTemplateConstraint(d.constraint);

                hgs.tpltMember++;
                bodyToBuffer(fd);
                hgs.tpltMember--;

                return true;
            }
            else if (AggregateDeclaration ad = onemember.isAggregateDeclaration())
            {
                buf.writestring(ad.kind());
                buf.writeByte(' ');
                buf.writestring(ad.ident.toString());
                buf.writeByte('(');
                hgs.visitTemplateParameters(hgs.ddoc ? d.origParameters : d.parameters, *buf);
                buf.writeByte(')');
                visitTemplateConstraint(d.constraint);
                visitBaseClasses(ad.isClassDeclaration());
                hgs.tpltMember++;

                if (ad.members)
                {
                    buf.writenl();
                    buf.writeByte('{');
                    buf.writenl();
                    buf.level++;

                    foreach (s; *ad.members)
                        hgs.toCBuffer(s, *buf);

                    buf.level--;
                    buf.writeByte('}');
                }
                else
                    buf.writeByte(';');

                buf.writenl();
                hgs.tpltMember--;
                return true;
            }
            else if (VarDeclaration vd = onemember.isVarDeclaration())
            {
                if (d.constraint)
                    return false;
                else if (storageClassToBuffer(*buf, vd.storage_class))
                    buf.writeByte(' ');

                if (vd.type)
                    hgs.typeToBuffer(vd.type, vd.ident, *buf);
                else
                    buf.writestring(vd.ident.toString());

                buf.writeByte('(');
                hgs.visitTemplateParameters(hgs.ddoc ? d.origParameters : d.parameters, *buf);
                buf.writeByte(')');

                if (vd._init)
                {
                    buf.writestring(" = ");
                    ExpInitializer ie = vd._init.isExpInitializer();

                    if (ie && (ie.exp.op == EXP.construct || ie.exp.op == EXP.blit))
                        hgs.expressionPrettyPrint((cast(AssignExp) ie.exp).e2, *buf);
                    else
                        hgs.initializerToBuffer(vd._init, *buf);
                }

                buf.writeByte(';');
                buf.writenl();
                return true;
            }

            return false;
        }

        void bodyToBuffer(FuncDeclaration f)
        {
            if (!f.fbody || (hgs.hdrgen && hgs.doFuncBodies == false
                    && !hgs.autoMember && !hgs.tpltMember && !hgs.insideFuncBody))
            {
                if (!f.fbody && (f.fensures || f.frequires))
                {
                    buf.writenl();
                    contractsToBuffer(f);
                }

                buf.writeByte(';');
                buf.writenl();
                return;
            }

            // there is no way to know if a function is nested
            // or not after parsing. We need scope information
            // for that, which is avaible during semantic
            // analysis. To overcome that, a simple mechanism
            // is implemented: everytime we print a function
            // body (templated or not) we increment a counter.
            // We decredement the counter when we stop
            // printing the function body.
            ++hgs.insideFuncBody;
            scope (exit)
            {
                --hgs.insideFuncBody;
            }

            const savetlpt = hgs.tpltMember;
            const saveauto = hgs.autoMember;
            hgs.tpltMember = 0;
            hgs.autoMember = 0;
            buf.writenl();
            bool requireDo = contractsToBuffer(f);

            if (requireDo)
            {
                buf.writestring("do");
                buf.writenl();
            }

            buf.writeByte('{');
            buf.writenl();
            buf.level++;
            hgs.statementToBuffer(f.fbody, *buf);
            buf.level--;
            buf.writeByte('}');
            buf.writenl();

            hgs.tpltMember = savetlpt;
            hgs.autoMember = saveauto;
        }

        void visitTemplateConstraint(Expression constraint)
        {
            if (!constraint)
                return;

            buf.writestring(" if (");
            hgs.expressionPrettyPrint(constraint, *buf);
            buf.writeByte(')');
        }

        /// Returns: whether `do` is needed to write the function body
        bool contractsToBuffer(FuncDeclaration f)
        {
            bool requireDo = false; // in{}

            if (f.frequires)
            {
                foreach (frequire; *f.frequires)
                {
                    buf.writestring("in");
                    if (auto es = frequire.isExpStatement())
                    {
                        assert(es.exp && es.exp.op == EXP.assert_);
                        buf.writestring(" (");
                        hgs.expressionPrettyPrint((cast(AssertExp) es.exp).e1, *buf);
                        buf.writeByte(')');
                        buf.writenl();
                        requireDo = false;
                    }
                    else
                    {
                        buf.writenl();
                        hgs.statementToBuffer(frequire, *buf);
                        requireDo = true;
                    }
                }
            }

            // out{}
            if (f.fensures)
            {
                foreach (fensure; *f.fensures)
                {
                    buf.writestring("out");

                    if (auto es = fensure.ensure.isExpStatement())
                    {
                        assert(es.exp && es.exp.op == EXP.assert_);
                        buf.writestring(" (");

                        if (fensure.id)
                        {
                            buf.writestring(fensure.id.toString());
                        }

                        buf.writestring("; ");
                        hgs.expressionPrettyPrint((cast(AssertExp) es.exp).e1, *buf);
                        buf.writeByte(')');
                        buf.writenl();
                        requireDo = false;
                    }
                    else
                    {
                        if (fensure.id)
                        {
                            buf.writeByte('(');
                            buf.writestring(fensure.id.toString());
                            buf.writeByte(')');
                        }

                        buf.writenl();
                        hgs.statementToBuffer(fensure.ensure, *buf);
                        requireDo = true;
                    }
                }
            }

            return requireDo;
        }

        void visitAttribDeclaration(AttribDeclaration d)
        {
            bool hasSTC;
            if (auto stcd = d.isStorageClassDeclaration)
            {
                hasSTC = storageClassToBuffer(*buf, stcd.stc);
            }

            if (!d.decl)
            {
                buf.writeByte(';');
                buf.writenl();
                return;
            }

            if (d.decl.length == 0 || (hgs.hdrgen && d.decl.length == 1
                    && (*d.decl)[0].isUnitTestDeclaration()))
            {
                // hack for https://issues.dlang.org/show_bug.cgi?id=8081
                if (hasSTC)
                    buf.writeByte(' ');
                buf.writestring("{}");
            }
            else if (d.decl.length == 1)
            {
                if (hasSTC)
                    buf.writeByte(' ');
                hgs.toCBuffer((*d.decl)[0], *buf);
                return;
            }
            else
            {
                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;

                foreach (de; *d.decl)
                    hgs.toCBuffer(de, *buf);

                buf.level--;
                buf.writeByte('}');
            }

            buf.writenl();
        }

    override:

        void visit(Dsymbol s)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring(s.toChars());
        }

        void visit(StaticAssert s)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring(s.kind());
            buf.writeByte('(');
            hgs.expressionPrettyPrint(s.exp, *buf);

            if (s.msgs)
            {
                foreach (m; (*s.msgs)[])
                {
                    buf.writestring(", ");
                    hgs.expressionPrettyPrint(m, *buf);
                }
            }

            buf.writestring(");");
            buf.writenl();
        }

        void visit(DebugSymbol s)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("debug = ");
            if (s.ident)
                buf.writestring(s.ident.toString());
            else
                buf.print(s.level);
            buf.writeByte(';');
            buf.writenl();
        }

        void visit(VersionSymbol s)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;

            buf.writestring("version = ");
            if (s.ident)
                buf.writestring(s.ident.toString());
            else
                buf.print(s.level);
            buf.writeByte(';');
            buf.writenl();
        }

        void visit(EnumMember em)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            assert(em.ident !is null, "ICE: Enum member identifier is null");
            buf.writestring(em.ident.toString());

            if (em.value)
            {
                buf.writestring(" = ");
                hgs.expressionPrettyPrint(em.value, *buf);
            }
        }

        void visit(Import imp)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (hgs.hdrgen && imp.id == Id.object)
                return; // object is imported by default
            else if (imp.isstatic)
                buf.writestring("static ");

            buf.writestring("import ");

            if (imp.aliasId)
            {
                buf.printf("%s = ", imp.aliasId.toChars());
            }

            foreach (const pid; imp.packages)
            {
                buf.write(pid.toString());
                buf.writeByte('.');
            }

            buf.writestring(imp.id.toString());

            if (imp.names.length)
            {
                buf.writestring(" : ");

                foreach (const i, const name; imp.names)
                {
                    if (i)
                        buf.writestring(", ");

                    const _alias = imp.aliases[i];

                    if (_alias)
                        buf.printf("%s = %s", _alias.toChars(), name.toChars());
                    else
                        buf.writestring(name.toChars());
                }
            }

            buf.writeByte(';');
            buf.writenl();
        }

        void visit(AliasThis d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("alias ");
            buf.writestring(d.ident.toString());
            buf.writestring(" this;\n");
        }

        void visit(AttribDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            visitAttribDeclaration(d);
        }

        void visit(StorageClassDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            visitAttribDeclaration(d);
        }

        void visit(DeprecatedDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("deprecated(");
            hgs.expressionPrettyPrint(d.msg, *buf);
            buf.writestring(") ");

            visitAttribDeclaration(d);
        }

        void visit(LinkDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("extern (");
            buf.writestring(linkageToString(d.linkage));
            buf.writestring(") ");
            visitAttribDeclaration(d);
        }

        void visit(CPPMangleDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            string s;
            final switch (d.cppmangle)
            {
            case CPPMANGLE.asClass:
                s = "class";
                break;
            case CPPMANGLE.asStruct:
                s = "struct";
                break;
            case CPPMANGLE.def:
                break;
            }

            buf.writestring("extern (C++, ");
            buf.writestring(s);
            buf.writestring(") ");

            visitAttribDeclaration(d);
        }

        void visit(VisibilityDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            visibilityToBuffer(*buf, d.visibility);
            AttribDeclaration ad = cast(AttribDeclaration) d;

            if (ad.decl.length <= 1)
                buf.writeByte(' ');

            if (ad.decl.length == 1 && (*ad.decl)[0].isVisibilityDeclaration)
                visitAttribDeclaration((*ad.decl)[0].isVisibilityDeclaration);
            else
                visitAttribDeclaration(d);
        }

        void visit(AlignDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (d.exps)
            {
                foreach (i, exp; (*d.exps)[])
                {
                    if (i)
                        buf.writeByte(' ');

                    buf.writestring("align (");
                    hgs.toCBuffer(exp, *buf);
                    buf.writeByte(')');
                }

                if (d.decl && d.decl.length < 2)
                    buf.writeByte(' ');
            }
            else
                buf.writestring("align ");

            visitAttribDeclaration(d.isAttribDeclaration());
        }

        void visit(AnonDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring(d.isunion ? "union" : "struct");
            buf.writenl();
            buf.writestring("{");
            buf.writenl();
            buf.level++;

            if (d.decl)
            {
                foreach (de; *d.decl)
                    hgs.toCBuffer(de, *buf);
            }

            buf.level--;
            buf.writestring("}");
            buf.writenl();
        }

        void visit(PragmaDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("pragma (");
            buf.writestring(d.ident.toString());

            if (d.args && d.args.length)
            {
                buf.writestring(", ");
                hgs.argsToBuffer(d.args, *buf);
            }

            buf.writeByte(')');

            // https://issues.dlang.org/show_bug.cgi?id=14690
            // Unconditionally perform a full output dump
            // for `pragma(inline)` declarations.
            const saved = hgs.doFuncBodies;
            if (d.ident == Id.Pinline)
                hgs.doFuncBodies = true;

            visitAttribDeclaration(d);
            hgs.doFuncBodies = saved;
        }

        void visit(ConditionalDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            hgs.conditionToBuffer(d.condition, *buf);

            if (d.decl || d.elsedecl)
            {
                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;

                if (d.decl)
                {
                    foreach (de; *d.decl)
                        hgs.toCBuffer(de, *buf);
                }

                buf.level--;
                buf.writeByte('}');

                if (d.elsedecl)
                {
                    buf.writenl();
                    buf.writestring("else");
                    buf.writenl();
                    buf.writeByte('{');
                    buf.writenl();
                    buf.level++;

                    foreach (de; *d.elsedecl)
                        hgs.toCBuffer(de, *buf);

                    buf.level--;
                    buf.writeByte('}');
                }
            }
            else
                buf.writeByte(':');

            buf.writenl();
        }

        void visit(StaticForeachDeclaration s)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            void foreachWithoutBody(ForeachStatement s)
            {
                buf.writestring(Token.toString(s.op));
                buf.writestring(" (");

                foreach (i, p; *s.parameters)
                {
                    if (i)
                        buf.writestring(", ");

                    if (storageClassToBuffer(*buf, p.storageClass))
                        buf.writeByte(' ');

                    if (p.type)
                        hgs.typeToBuffer(p.type, p.ident, *buf);
                    else
                        buf.writestring(p.ident.toString());
                }

                buf.writestring("; ");
                hgs.expressionPrettyPrint(s.aggr, *buf);
                buf.writeByte(')');
                buf.writenl();
            }

            void foreachRangeWithoutBody(ForeachRangeStatement s)
            {
                // s.op ( prm ; lwr .. upr )
                buf.writestring(Token.toString(s.op));
                buf.writestring(" (");

                if (s.prm.type)
                    hgs.typeToBuffer(s.prm.type, s.prm.ident, *buf);
                else
                    buf.writestring(s.prm.ident.toString());

                buf.writestring("; ");
                hgs.expressionPrettyPrint(s.lwr, *buf);
                buf.writestring(" .. ");
                hgs.expressionPrettyPrint(s.upr, *buf);
                buf.writeByte(')');
                buf.writenl();
            }

            buf.writestring("static ");

            if (s.sfe.aggrfe)
            {
                foreachWithoutBody(s.sfe.aggrfe);
            }
            else
            {
                assert(s.sfe.rangefe);
                foreachRangeWithoutBody(s.sfe.rangefe);
            }

            buf.writeByte('{');
            buf.writenl();
            buf.level++;
            visitAttribDeclaration(s);
            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visit(MixinDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("mixin(");
            hgs.argsToBuffer(d.exps, *buf, null);
            buf.writestring(");");
            buf.writenl();
        }

        void visit(UserAttributeDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("@(");
            hgs.argsToBuffer(d.atts, *buf);
            buf.writeByte(')');
            visitAttribDeclaration(d);
        }

        void visit(TemplateDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            version (none)
            {
                // Should handle template functions for doc generation
                if (onemember && onemember.isFuncDeclaration())
                    buf.writestring("foo ");
            }

            if ((hgs.hdrgen || hgs.fullDump) && visitEponymousMember(d))
                return;
            else if (hgs.ddoc)
                buf.writestring(d.kind());
            else
                buf.writestring("template");

            buf.writeByte(' ');
            buf.writestring(d.ident.toString());
            buf.writeByte('(');
            hgs.visitTemplateParameters(hgs.ddoc ? d.origParameters : d.parameters, *buf);
            buf.writeByte(')');
            visitTemplateConstraint(d.constraint);

            if (hgs.hdrgen || hgs.fullDump)
            {
                hgs.tpltMember++;
                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;

                foreach (s; *d.members)
                    hgs.toCBuffer(s, *buf);

                buf.level--;
                buf.writeByte('}');
                buf.writenl();
                hgs.tpltMember--;
            }
        }

        void visit(TemplateInstance ti)
        {
            trace;

            if (hgs.childCountOfModule > 1 || !hgs.hdrgen)
            {
                buf.writestring(ti.name.toChars());
                hgs.tiargsToBuffer(ti, *buf);

                if (hgs.fullDump)
                {
                    buf.writenl();
                    hgs.dumpTemplateInstance(ti, *buf);
                }
            }
        }

        void visit(TemplateMixin tm)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if ((cast(TypeIdentifier) tm.tqual).ident is Id.CMain && !hgs.vcg_ast)
                return;

            buf.writestring("mixin ");
            hgs.typeToBuffer(tm.tqual, null, *buf);
            hgs.tiargsToBuffer(tm, *buf);

            if (tm.ident && memcmp(tm.ident.toString().ptr, cast(const(char)*) "__mixin", 7) != 0)
            {
                buf.writeByte(' ');
                buf.writestring(tm.ident.toString());
            }

            buf.writeByte(';');
            buf.writenl();

            if (hgs.fullDump)
                hgs.dumpTemplateInstance(tm, *buf);
        }

        void visit(EnumDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            auto oldInEnumDecl = hgs.inEnumDecl;
            scope (exit)
                hgs.inEnumDecl = oldInEnumDecl;

            hgs.inEnumDecl = d;
            buf.writestring("enum");

            if (d.ident)
            {
                buf.writestring(" ");
                buf.writestring(d.ident.toString());
            }

            if (d.memtype)
            {
                buf.writestring(" : ");
                hgs.typeToBuffer(d.memtype, null, *buf);
            }

            if (!d.members)
            {
                buf.writeByte(';');
                buf.writenl();
                return;
            }

            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            foreach (em; *d.members)
            {
                if (!em)
                    continue;

                hgs.toCBuffer(em, *buf);
                buf.writeByte(',');
                buf.writenl();
            }

            buf.level--;
            buf.writeByte('}');
            buf.writenl();

            if (!hgs.importcHdr || !d.ident)
                return;

            /* C enums get their members inserted into the symbol table of the enum declaration.
             * This is accomplished in addEnumMembersToSymtab().
             * But when generating D code from ImportC code, D rulez are followed.
             * Accomplish this by generating an alias declaration for each member
             */
            foreach (em; *d.members)
            {
                if (!em)
                    continue;

                buf.writestring("alias ");
                buf.writestring(em.ident.toString);
                buf.writestring(" = ");
                buf.writestring(d.ident.toString);
                buf.writeByte('.');
                buf.writestring(em.ident.toString);
                buf.writeByte(';');
                buf.writenl();
            }
        }

        void visit(Nspace d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring("extern (C++, ");
            buf.writestring(d.ident.toString());
            buf.writeByte(')');
            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;

            foreach (s; *d.members)
                hgs.toCBuffer(s, *buf);

            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visit(StructDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            //printf("visitStructDeclaration() %s\n", d.ident.toChars());
            buf.writestring(d.kind());
            buf.writeByte(' ');

            if (!d.isAnonymous())
                buf.writestring(d.toChars());

            if (!d.members)
            {
                buf.writeByte(';');
                buf.writenl();
                return;
            }

            buf.writenl();
            buf.writeByte('{');
            buf.writenl();
            buf.level++;
            hgs.insideAggregate++;

            foreach (s; *d.members)
                hgs.toCBuffer(s, *buf);

            hgs.insideAggregate--;
            buf.level--;
            buf.writeByte('}');
            buf.writenl();
        }

        void visit(ClassDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (!d.isAnonymous())
            {
                buf.writestring(d.kind());
                buf.writeByte(' ');
                buf.writestring(d.ident.toString());
            }

            visitBaseClasses(d);

            if (d.members)
            {
                buf.writenl();
                buf.writeByte('{');
                buf.writenl();
                buf.level++;
                hgs.insideAggregate++;

                foreach (s; *d.members)
                    hgs.toCBuffer(s, *buf);

                hgs.insideAggregate--;
                buf.level--;
                buf.writeByte('}');
            }
            else
                buf.writeByte(';');

            buf.writenl();
        }

        void visit(AliasDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (d.storage_class & STC.local)
                return;
            else if (d.adFlags & d.hidden)
                return;

            buf.writestring("alias ");

            if (d.aliassym)
            {
                buf.writestring(d.ident.toString());
                buf.writestring(" = ");

                if (storageClassToBuffer(*buf, d.storage_class))
                    buf.writeByte(' ');

                if (d.aliassym.ident !is null)
                {
                    /*
                    https://issues.dlang.org/show_bug.cgi?id=23223
                    https://issues.dlang.org/show_bug.cgi?id=23222
                    This special case (initially just for modules) avoids some segfaults
                    and nicer -vcg-ast output.
                    */
                    buf.writestring(d.aliassym.ident.toString());
                }
                else
                {
                    hgs.toCBuffer(d.aliassym, *buf);

                    char lastChar = (*buf)[][$ - 1];
                    if (lastChar == ';' || lastChar == '\n')
                        return;
                }
            }
            else if (d.type.ty == Tfunction)
            {
                if (storageClassToBuffer(*buf, d.storage_class))
                    buf.writeByte(' ');

                hgs.typeToBuffer(d.type, d.ident, *buf);
            }
            else if (d.ident)
            {
                hgs.declstring = (d.ident == Id.string || d.ident == Id.wstring
                        || d.ident == Id.dstring);
                buf.writestring(d.ident.toString());
                buf.writestring(" = ");

                if (storageClassToBuffer(*buf, d.storage_class))
                    buf.writeByte(' ');

                hgs.typeToBuffer(d.type, null, *buf);
                hgs.declstring = false;
            }

            buf.writeByte(';');
            buf.writenl();
        }

        void visit(AliasAssign d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            buf.writestring(d.ident.toString());
            buf.writestring(" = ");

            if (d.aliassym)
                hgs.toCBuffer(d.aliassym, *buf);
            else // d.type
                hgs.typeToBuffer(d.type, null, *buf);

            buf.writeByte(';');
            buf.writenl();
        }

        void visit(VarDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (d.storage_class & STC.local)
                return;

            hgs.visitVarDecl(d, false, *buf);
            buf.writeByte(';');
            buf.writenl();
        }

        void visit(FuncDeclaration f)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            //printf("FuncDeclaration::toCBuffer() '%s'\n", f.toChars());
            if (storageClassToBuffer(*buf, f.storage_class & STC.lhsHeaderAttributes))
            {
                buf.writeByte(' ');
            }

            auto tf = f.type.isTypeFunction();
            hgs.typeToBuffer(tf, f.ident, *buf);

            if (hgs.hdrgen)
            {
                // if the return type is missing (e.g. ref functions or auto)
                // https://issues.dlang.org/show_bug.cgi?id=20090
                // constructors are an exception: they don't have an explicit return
                // type but we still don't output the body.
                if ((!f.isCtorDeclaration() && !tf.next) || f.storage_class & STC.auto_)
                {
                    hgs.autoMember++;
                    bodyToBuffer(f);
                    hgs.autoMember--;
                }
                else if (hgs.tpltMember == 0 && hgs.doFuncBodies == false && !hgs.insideFuncBody)
                {
                    if (!f.fbody)
                    {
                        // this can happen on interfaces / abstract functions, see `allowsContractWithoutBody`
                        if (f.fensures || f.frequires)
                            buf.writenl();

                        contractsToBuffer(f);
                    }

                    buf.writeByte(';');
                    buf.writenl();
                }
                else
                    bodyToBuffer(f);
            }
            else
                bodyToBuffer(f);
        }

        void visit(FuncLiteralDeclaration f)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (f.type.ty == Terror)
            {
                buf.writestring("__error");
                return;
            }
            else if (f.tok != TOK.reserved)
            {
                buf.writestring(f.kind());
                buf.writeByte(' ');
            }
            TypeFunction tf = cast(TypeFunction) f.type;

            if (!f.inferRetType && tf.next)
                hgs.typeToBuffer(tf.next, null, *buf);

            hgs.parametersToBuffer(tf.parameterList, *buf);

            // https://issues.dlang.org/show_bug.cgi?id=20074
            void printAttribute(string str)
            {
                buf.writeByte(' ');
                buf.writestring(str);
            }

            tf.attributesApply(&printAttribute);

            CompoundStatement cs = f.fbody.isCompoundStatement();
            Statement s1;

            if (f.semanticRun >= PASS.semantic3done && cs)
            {
                s1 = (*cs.statements)[cs.statements.length - 1];
            }
            else
                s1 = !cs ? f.fbody : null;

            ReturnStatement rs = s1 ? s1.endsWithReturnStatement() : null;

            if (rs && rs.exp)
            {
                buf.writestring(" => ");
                hgs.expressionPrettyPrint(rs.exp, *buf);
            }
            else
            {
                hgs.tpltMember++;
                bodyToBuffer(f);
                hgs.tpltMember--;
            }
        }

        void visit(PostBlitDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (d.type !is null)
            {
                auto tf = d.type.isTypeFunction();

                if (storageClassToBuffer(*buf, d.storage_class & STC.lhsHeaderAttributes))
                    buf.writeByte(' ');

                hgs.typeToBuffer(tf, d.ident, *buf);
                bodyToBuffer(d);
            }
        }

        void visit(DtorDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (d.type !is null)
            {
                auto tf = d.type.isTypeFunction();

                if (storageClassToBuffer(*buf, d.storage_class & STC.lhsHeaderAttributes))
                    buf.writeByte(' ');

                hgs.typeToBuffer(tf, d.ident, *buf);
                bodyToBuffer(d);
            }
        }

        void visit(StaticCtorDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            hgs.writeTypeFunctionAttributes(d.type !is null ? d.type.isTypeFunction() : null,
                    *buf, d.storage_class & STC.lhsHeaderMCtorAttributes,
                    d.storage_class & STC.rhsHeaderMCtorAttributes, (TypeFunction tf) {
                if (d.isSharedStaticCtorDeclaration())
                    buf.writestring("shared ");

                buf.writestring("static this()");
            });

            if (hgs.hdrgen && !hgs.tpltMember)
            {
                buf.writeByte(';');
                buf.writenl();
            }
            else
                bodyToBuffer(d);
        }

        void visit(StaticDtorDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            hgs.writeTypeFunctionAttributes(d.type !is null ? d.type.isTypeFunction() : null,
                    *buf, d.storage_class & STC.lhsHeaderMCtorAttributes,
                    d.storage_class & STC.rhsHeaderMCtorAttributes, (TypeFunction tf) {
                if (d.isSharedStaticDtorDeclaration())
                    buf.writestring("shared ");

                buf.writestring("static ~this()");
            });

            if (hgs.hdrgen && !hgs.tpltMember)
            {
                buf.writeByte(';');
                buf.writenl();
            }
            else
                bodyToBuffer(d);
        }

        void visit(InvariantDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (hgs.hdrgen)
                return;
            else if (storageClassToBuffer(*buf, d.storage_class))
                buf.writeByte(' ');

            // FIXME: no attributes would be emitted here for semantic 3

            buf.writestring("invariant");

            if (auto es = d.fbody.isExpStatement())
            {
                assert(es.exp && es.exp.op == EXP.assert_);
                buf.writestring(" (");
                hgs.expressionPrettyPrint((cast(AssertExp) es.exp).e1, *buf);
                buf.writestring(");");
                buf.writenl();
            }
            else
            {
                bodyToBuffer(d);
            }
        }

        void visit(UnitTestDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (hgs.hdrgen)
                return;
            else if (storageClassToBuffer(*buf, d.storage_class))
                buf.writeByte(' ');

            // FIXME: no attributes would be emitted here for semantic 3

            buf.writestring("unittest");
            bodyToBuffer(d);
        }

        void visit(BitFieldDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (storageClassToBuffer(*buf, d.storage_class))
                buf.writeByte(' ');

            Identifier id = d.isAnonymous() ? null : d.ident;
            hgs.typeToBuffer(d.type, id, *buf);
            buf.writestring(" : ");
            hgs.expressionPrettyPrint(d.width, *buf);
            buf.writeByte(';');
            buf.writenl();
        }

        void visit(NewDeclaration d)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            if (storageClassToBuffer(*buf, d.storage_class & ~STC.static_))
                buf.writeByte(' ');

            buf.writestring("new();");
        }

        void visit(Module m)
        {
            hgs.childCountOfModule++;
            scope (exit)
                hgs.childCountOfModule--;
            trace;

            hgs.moduleToBuffer(m, *buf);
        }
    }

    extern (C++) final class TemplateParameterPrettyPrintVisitor : Visitor
    {
        alias visit = Visitor.visit;
        OutBuffer* buf;
        HdrGenState* hgs;

        override void visit(TemplateTypeParameter tp)
        {
            buf.writestring(tp.ident.toString());

            if (tp.specType)
            {
                buf.writestring(" : ");
                hgs.typeToBuffer(tp.specType, null, *buf);
            }

            if (tp.defaultType)
            {
                buf.writestring(" = ");
                hgs.typeToBuffer(tp.defaultType, null, *buf);
            }
        }

        override void visit(TemplateThisParameter tp)
        {
            buf.writestring("this ");
            visit(cast(TemplateTypeParameter) tp);
        }

        override void visit(TemplateAliasParameter tp)
        {
            buf.writestring("alias ");

            if (tp.specType)
                hgs.typeToBuffer(tp.specType, tp.ident, *buf);
            else
                buf.writestring(tp.ident.toString());

            if (tp.specAlias)
            {
                buf.writestring(" : ");
                hgs.objectToBuffer(tp.specAlias, *buf);
            }

            if (tp.defaultAlias)
            {
                buf.writestring(" = ");
                hgs.objectToBuffer(tp.defaultAlias, *buf);
            }
        }

        override void visit(TemplateValueParameter tp)
        {
            hgs.typeToBuffer(tp.valType, tp.ident, *buf);

            if (tp.specValue)
            {
                buf.writestring(" : ");
                hgs.expressionPrettyPrint(tp.specValue, *buf);
            }

            if (tp.defaultValue)
            {
                buf.writestring(" = ");
                hgs.expressionPrettyPrint(tp.defaultValue, *buf);
            }
        }

        override void visit(TemplateTupleParameter tp)
        {
            buf.writestring(tp.ident.toString());
            buf.writestring("...");
        }
    }

    extern (C++) final class ConditionPrettyPrintVisitor : Visitor
    {
        alias visit = Visitor.visit;
        OutBuffer* buf;
        HdrGenState* hgs;

        override void visit(DebugCondition c)
        {
            buf.writestring("debug (");

            if (c.ident)
                buf.writestring(c.ident.toString());
            else
                buf.print(c.level);

            buf.writeByte(')');
        }

        override void visit(VersionCondition c)
        {
            buf.writestring("version (");

            if (c.ident)
                buf.writestring(c.ident.toString());
            else
                buf.print(c.level);

            buf.writeByte(')');
        }

        override void visit(StaticIfCondition c)
        {
            buf.writestring("static if (");
            hgs.expressionPrettyPrint(c.exp, *buf);
            buf.writeByte(')');
        }
    }
}

private:

// dfmt off
static immutable string[7] TableOfVisibilityStrings = [
    Visibility.Kind.none: "none",
    Visibility.Kind.private_: "private",
    Visibility.Kind.package_: "package",
    Visibility.Kind.protected_: "protected",
    Visibility.Kind.public_: "public",
    Visibility.Kind.export_: "export"
];

static immutable string[7] TableOfLinkageStrings = [
    LINK.default_: null,
    LINK.d: "D",
    LINK.c: "C",
    LINK.cpp: "C++",
    LINK.windows: "Windows",
    LINK.objc: "Objective-C",
    LINK.system: "System"
];

static immutable string[EXP.max + 1] TableOfExpressionTypeStrings = [
    EXP.type: "type",
    EXP.error: "error",
    EXP.objcClassReference: "class",

    EXP.mixin_: "mixin",
    EXP.import_: "import",
    EXP.dotVariable: "dotvar",
    EXP.scope_: "scope",
    EXP.identifier: "identifier",
    EXP.this_: "this",
    EXP.super_: "super",
    EXP.int64: "long",
    EXP.float64: "double",
    EXP.complex80: "creal",
    EXP.null_: "null",
    EXP.string_: "string",
    EXP.arrayLiteral: "arrayliteral",
    EXP.assocArrayLiteral: "assocarrayliteral",
    EXP.classReference: "classreference",
    EXP.file: "__FILE__",
    EXP.fileFullPath: "__FILE_FULL_PATH__",
    EXP.line: "__LINE__",
    EXP.moduleString: "__MODULE__",
    EXP.functionString: "__FUNCTION__",
    EXP.prettyFunction: "__PRETTY_FUNCTION__",
    EXP.typeid_: "typeid",
    EXP.is_: "is",
    EXP.assert_: "assert",
    EXP.halt: "halt",
    EXP.template_: "template",
    EXP.dSymbol: "symbol",
    EXP.function_: "function",
    EXP.variable: "var",
    EXP.symbolOffset: "symoff",
    EXP.structLiteral: "structLiteral",
    EXP.compoundLiteral: "compoundliteral",
    EXP.arrayLength: "arraylength",
    EXP.delegatePointer: "delegateptr",
    EXP.delegateFunctionPointer: "delegatefuncptr",
    EXP.remove: "remove",
    EXP.tuple: "sequence",
    EXP.traits: "__traits",
    EXP.overloadSet: "__overloadset",
    EXP.void_: "void",
    EXP.vectorArray: "vectorarray",
    EXP._Generic: "_Generic",

    // post
    EXP.dotTemplateInstance: "dotti",
    EXP.dotIdentifier: "dotid",
    EXP.dotTemplateDeclaration: "dottd",
    EXP.dot: ".",
    EXP.dotType: "dottype",
    EXP.plusPlus: "++",
    EXP.minusMinus: "--",
    EXP.prePlusPlus: "++",
    EXP.preMinusMinus: "--",
    EXP.call: "call",
    EXP.slice: "..",
    EXP.array: "[]",
    EXP.index: "[i]",
    EXP.delegate_: "delegate",
    EXP.address: "&",
    EXP.star: "*",
    EXP.negate: "-",
    EXP.uadd: "+",
    EXP.not: "!",
    EXP.tilde: "~",
    EXP.delete_: "delete",
    EXP.new_: "new",
    EXP.newAnonymousClass: "newanonclass",
    EXP.cast_: "cast",

    EXP.vector: "__vector",
    EXP.pow: "^^",
    EXP.mul: "*",
    EXP.div: "/",
    EXP.mod: "%",
    EXP.add: "+",
    EXP.min: "-",
    EXP.concatenate: "~",

    EXP.leftShift: "<<",
    EXP.rightShift: ">>",
    EXP.unsignedRightShift: ">>>",

    EXP.lessThan: "<",
    EXP.lessOrEqual: "<=",
    EXP.greaterThan: ">",
    EXP.greaterOrEqual: ">=",
    EXP.in_: "in",
    EXP.equal: "==",
    EXP.notEqual: "!=",
    EXP.identity: "is",
    EXP.notIdentity: "!is",

    EXP.and: "&",
    EXP.xor: "^",
    EXP.or: "|",
    EXP.andAnd: "&&",
    EXP.orOr: "||",

    EXP.question: "?",
    EXP.assign: "=",
    EXP.construct: "=",
    EXP.blit: "=",
    EXP.addAssign: "+=",
    EXP.minAssign: "-=",
    EXP.concatenateAssign: "~=",
    EXP.concatenateElemAssign: "~=",
    EXP.concatenateDcharAssign: "~=",
    EXP.mulAssign: "*=",
    EXP.divAssign: "/=",
    EXP.modAssign: "%=",
    EXP.powAssign: "^^=",
    EXP.leftShiftAssign: "<<=",
    EXP.rightShiftAssign: ">>=",
    EXP.unsignedRightShiftAssign: ">>>=",
    EXP.andAssign: "&=",
    EXP.orAssign: "|=",
    EXP.xorAssign: "^=",

    EXP.comma: ",",
    EXP.declaration: "declaration",
    EXP.interval: "interval",
    EXP.loweredAssignExp: "="
];

struct StorageClassStringMap
{
    StorageClass stc;
    string id;
}

static immutable StorageClassStringMap[] TableOfStorageClassStrings = [
    StorageClassStringMap(STC.auto_, Token.toString(TOK.auto_)),
    StorageClassStringMap(STC.scope_, Token.toString(TOK.scope_)),
    StorageClassStringMap(STC.static_, Token.toString(TOK.static_)),
    StorageClassStringMap(STC.extern_, Token.toString(TOK.extern_)),
    StorageClassStringMap(STC.const_, Token.toString(TOK.const_)),
    StorageClassStringMap(STC.final_, Token.toString(TOK.final_)),
    StorageClassStringMap(STC.abstract_, Token.toString(TOK.abstract_)),
    StorageClassStringMap(STC.synchronized_, Token.toString(TOK.synchronized_)),
    StorageClassStringMap(STC.deprecated_, Token.toString(TOK.deprecated_)),
    StorageClassStringMap(STC.override_, Token.toString(TOK.override_)),
    StorageClassStringMap(STC.lazy_, Token.toString(TOK.lazy_)),
    StorageClassStringMap(STC.alias_, Token.toString(TOK.alias_)),
    StorageClassStringMap(STC.out_, Token.toString(TOK.out_)),
    StorageClassStringMap(STC.in_, Token.toString(TOK.in_)),
    StorageClassStringMap(STC.manifest, Token.toString(TOK.enum_)),
    StorageClassStringMap(STC.immutable_, Token.toString(TOK.immutable_)),
    StorageClassStringMap(STC.shared_, Token.toString(TOK.shared_)),
    StorageClassStringMap(STC.nothrow_, Token.toString(TOK.nothrow_)),
    StorageClassStringMap(STC.wild, Token.toString(TOK.inout_)),
    StorageClassStringMap(STC.pure_, Token.toString(TOK.pure_)),
    StorageClassStringMap(STC.ref_, Token.toString(TOK.ref_)),
    StorageClassStringMap(STC.return_, Token.toString(TOK.return_)),
    StorageClassStringMap(STC.gshared, Token.toString(TOK.gshared)),
    StorageClassStringMap(STC.nogc, "@nogc"),
    StorageClassStringMap(STC.live, "@live"),
    StorageClassStringMap(STC.property, "@property"),
    StorageClassStringMap(STC.safe, "@safe"),
    StorageClassStringMap(STC.trusted, "@trusted"),
    StorageClassStringMap(STC.system, "@system"),
    StorageClassStringMap(STC.disable, "@disable"),
    StorageClassStringMap(STC.future, "@__future"),
    StorageClassStringMap(STC.local, "__local"),
];
// dfmt on

void linkageToBuffer(ref OutBuffer buf, LINK linkage) @safe nothrow pure
{
    const s = linkageToString(linkage);
    if (s.length)
    {
        buf.writestring("extern (");
        buf.writestring(s);
        buf.writeByte(')');
    }
}

/**
  The names __DATE__, __TIME__,__EOF__, __VENDOR__, __TIMESTAMP__, __VERSION__
   are special to the D lexer and cannot be used as D source variable names.

  Params:
       id = name to check

  Returns:
       true if special C name
*/
bool isSpecialCName(Identifier id)
{
    auto s = id.toString();
    return s.length >= 7 && s[0] == '_' && s[1] == '_' && (id == Id.DATE
            || id == Id.TIME || id == Id.EOFX || id == Id.VENDOR
            || id == Id.TIMESTAMP || id == Id.VERSIONX);
}
