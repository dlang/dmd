// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.objc;

import ddmd.arraytypes, ddmd.cond, ddmd.dclass, ddmd.dmangle, ddmd.dmodule, ddmd.dscope, ddmd.dstruct, ddmd.expression, ddmd.func, ddmd.globals, ddmd.id, ddmd.identifier, ddmd.mtype, ddmd.root.outbuffer, ddmd.root.stringtable;

extern(C++) void objc_initSymbols();

struct ObjcSelector
{
    // MARK: Selector
    extern (C++) static __gshared StringTable stringtable;
    extern (C++) static __gshared StringTable vTableDispatchSelectors;
    extern (C++) static __gshared int incnum = 0;
    const(char)* stringvalue;
    size_t stringlen;
    size_t paramCount;

    extern (C++) static void _init()
    {
        stringtable._init();
    }

    extern (D) this(const(char)* sv, size_t len, size_t pcount)
    {
        stringvalue = sv;
        stringlen = len;
        paramCount = pcount;
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s)
    {
        size_t len = 0;
        size_t pcount = 0;
        const(char)* i = s;
        while (*i != 0)
        {
            ++len;
            if (*i == ':')
                ++pcount;
            ++i;
        }
        return lookup(s, len, pcount);
    }

    extern (C++) static ObjcSelector* lookup(const(char)* s, size_t len, size_t pcount)
    {
        StringValue* sv = stringtable.update(s, len);
        ObjcSelector* sel = cast(ObjcSelector*)sv.ptrvalue;
        if (!sel)
        {
            sel = new ObjcSelector(sv.toDchars(), len, pcount);
            sv.ptrvalue = cast(char*)sel;
        }
        return sel;
    }

    extern (C++) static ObjcSelector* create(FuncDeclaration fdecl)
    {
        OutBuffer buf;
        size_t pcount = 0;
        TypeFunction ftype = cast(TypeFunction)fdecl.type;
        // Special case: property setter
        if (ftype.isproperty && ftype.parameters && ftype.parameters.dim == 1)
        {
            // rewrite "identifier" as "setIdentifier"
            char firstChar = fdecl.ident.string[0];
            if (firstChar >= 'a' && firstChar <= 'z')
                firstChar = cast(char)(firstChar - 'a' + 'A');
            buf.writestring("set");
            buf.writeByte(firstChar);
            buf.write(fdecl.ident.string + 1, fdecl.ident.len - 1);
            buf.writeByte(':');
            goto Lcomplete;
        }
        // write identifier in selector
        buf.write(fdecl.ident.string, fdecl.ident.len);
        // add mangled type and colon for each parameter
        if (ftype.parameters && ftype.parameters.dim)
        {
            buf.writeByte('_');
            Parameters* arguments = ftype.parameters;
            size_t dim = Parameter.dim(arguments);
            for (size_t i = 0; i < dim; i++)
            {
                Parameter arg = Parameter.getNth(arguments, i);
                mangleToBuffer(arg.type, &buf);
                buf.writeByte(':');
            }
            pcount = dim;
        }
    Lcomplete:
        buf.writeByte('\0');
        return lookup(cast(const(char)*)buf.data, buf.size, pcount);
    }
}

struct Objc_ClassDeclaration
{
    // true if this is an Objective-C class/interface
    bool objc;

    // MARK: Objc_ClassDeclaration
    extern (C++) bool isInterface()
    {
        return objc;
    }
}

struct Objc_FuncDeclaration
{
    FuncDeclaration fdecl;
    // Objective-C method selector (member function only)
    ObjcSelector* selector;

    extern (D) this(FuncDeclaration fdecl)
    {
        this.fdecl = fdecl;
        selector = null;
    }
}

// MARK: semantic
extern (C++) void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration cd)
{
    cd.objc.objc = true;
}

extern (C++) void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration id, Scope* sc)
{
    if (sc.linkage == LINKobjc)
        id.objc.objc = true;
}

// MARK: semantic
extern (C++) void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration fd, Scope* sc)
{
    if (!fd.userAttribDecl)
        return;
    Expressions* udas = fd.userAttribDecl.getAttributes();
    arrayExpressionSemantic(udas, sc, true);
    for (size_t i = 0; i < udas.dim; i++)
    {
        Expression uda = (*udas)[i];
        assert(uda.type);
        if (uda.type.ty != Ttuple)
            continue;
        Expressions* exps = (cast(TupleExp)uda).exps;
        for (size_t j = 0; j < exps.dim; j++)
        {
            Expression e = (*exps)[j];
            assert(e.type);
            if (e.type.ty != Tstruct)
                continue;
            StructLiteralExp literal = cast(StructLiteralExp)e;
            assert(literal.sd);
            if (!objc_isUdaSelector(literal.sd))
                continue;
            if (fd.objc.selector)
            {
                fd.error("can only have one Objective-C selector per method");
                return;
            }
            assert(literal.elements.dim == 1);
            StringExp se = (*literal.elements)[0].toStringExp();
            assert(se);
            fd.objc.selector = ObjcSelector.lookup(cast(const(char)*)se.toUTF8(sc).string);
        }
    }
}

extern (C++) bool objc_isUdaSelector(StructDeclaration sd)
{
    if (sd.ident != Id.udaSelector || !sd.parent)
        return false;
    Module _module = sd.parent.isModule();
    return _module && _module.isCoreModule(Id.attribute);
}

extern (C++) void objc_FuncDeclaration_semantic_validateSelector(FuncDeclaration fd)
{
    if (!fd.objc.selector)
        return;
    TypeFunction tf = cast(TypeFunction)fd.type;
    if (fd.objc.selector.paramCount != tf.parameters.dim)
        fd.error("number of colons in Objective-C selector must match number of parameters");
    if (fd.parent && fd.parent.isTemplateInstance())
        fd.error("template cannot have an Objective-C selector attached");
}

extern (C++) void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration fd)
{
    if (fd.linkage != LINKobjc && fd.objc.selector)
        fd.error("must have Objective-C linkage to attach a selector");
}

// MARK: init
extern (C++) void objc_tryMain_dObjc()
{
    VersionCondition.addPredefinedGlobalIdent("D_ObjectiveC");
}

extern (C++) void objc_tryMain_init()
{
    objc_initSymbols();
    ObjcSelector._init();
}
